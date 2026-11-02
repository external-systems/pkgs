# Headroom: context compression layer for AI agents (proxy + MCP server).
# Packaged from the prebuilt manylinux_2_28 x86_64 wheel (cp310-abi3,
# CPython 3.10-3.13): the wheel carries the maturin/Rust extension, so
# the cdylib is never rebuilt from source. Every runtime dependency comes
# from nixpkgs' python313Packages.
#
# slim = true: core + proxy + code + mcp only (~3.8 GB smaller closure).
# Proxy serve and the MCP compress/retrieve roundtrip work; features that
# need torch or embedding models (memory, learn, image OCR, evals) do not.
{
  lib,
  fetchurl,
  fetchPypi,
  uv,
  autoPatchelfHook,
  stdenv,
  python313Packages,
  slim ? false,
}: let
  py = python313Packages.overrideScope (final: previous: {
    # Headroom 0.42 requires filelock>=4.2.1.
    filelock = previous.filelock.overrideAttrs (finalAttrs: previousAttrs: {
      version = "4.2.6";
      src = fetchPypi {
        pname = "filelock";
        inherit (finalAttrs) version;
        hash = "sha256-7nr47eNtyvEuEBbZ98OmPs1Ul9RvhdqyG4x3m4+UTpc=";
      };
      nativeBuildInputs = previousAttrs.nativeBuildInputs ++ [final.hatch-fancy-pypi-readme];
    });
    # Build-only virtualenv still requires filelock 3.x.
    inherit (python313Packages) virtualenv;

    # Rich 15 omits the filename from the error panel expected by this test.
    typer = previous.typer.overrideAttrs (_: {
      disabledTests = ["test_file_error"];
    });

    # Headroom requires the MCP 1.x low-level server API, which MCP 2.x removed.
    mcp = previous.mcp.overrideAttrs (finalAttrs: previousAttrs: {
      version = "1.30.0";
      src = fetchPypi {
        pname = "mcp";
        inherit (finalAttrs) version;
        hash = "sha256-RFQUYl/OXClfqlBbsRus7OZhq29AKNV8k121eCC3o+Q=";
      };
      dependencies = with final;
        [
          anyio
          httpx-sse
          httpx
          jsonschema
          pydantic-settings
          pydantic
          pyjwt
          python-multipart
          sse-starlette
          starlette
          typing-extensions
          typing-inspection
          uvicorn
        ]
        ++ pyjwt.optional-dependencies.crypto;
      propagatedBuildInputs = finalAttrs.dependencies ++ [final.python];
      nativeCheckInputs = previousAttrs.nativeCheckInputs ++ [uv final.websockets];
      nativeBuildInputs = previousAttrs.nativeBuildInputs ++ [uv final.websockets];
      disabledTests =
        previousAttrs.disabledTests
        ++ [
          "test_command_execution"
          "test_lifespan_cleanup_executed"
        ];
    });
  });
  version = "0.42.0";

  # headroom-ai core + proxy + code + mcp.
  slimDeps = with py; [
    # core
    tiktoken
    pydantic
    litellm
    click
    rich
    opentelemetry-api
    ast-grep-cli
    pyyaml
    tomlkit
    # truststore joined core in headroom 0.38.
    truststore
    hf-xet
    filelock
    # proxy
    fastapi
    uvicorn
    orjson
    httpx
    h2
    openai
    mcp
    zstandard
    websockets
    watchdog
    magika
    transformers
    # code (AST compression)
    tree-sitter-language-pack
    tree-sitter
    # mcp (server tools; shared with proxy)
    starlette
  ];

  # headroom-ai[all] on top of the slim set: ml, memory, relevance, image,
  # reports, otel, evals, html, spreadsheet, voice.
  fullDeps =
    slimDeps
    ++ (with py; [
      onnxruntime
      sqlite-vec
      torch
      huggingface-hub
      sentence-transformers
      fastembed
      numpy
      pillow
      sentencepiece
      rapidocr
      jinja2
      opentelemetry-sdk
      opentelemetry-exporter-otlp-proto-http
      datasets
      scikit-learn
      anthropic
      trafilatura
      openpyxl
      xlrd
    ]);
in
  py.buildPythonApplication {
    pname =
      if slim
      then "headroom-ai-slim"
      else "headroom-ai";
    inherit version;
    format = "wheel";

    # fetchurl keeps the real PyPI file name, which the wheel install
    # hook needs (it globs dist/*.whl).
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/82/76/34c9b66a878b7ce69aa27761c41f341a8863945f2a681f8d2920c778c3d7/headroom_ai-${version}-cp310-abi3-manylinux_2_28_x86_64.whl";
      hash = "sha256-+7POuPbD8gjtzDqtQ8DgPg20VjbZ0gYVJa0NChZtoUY=";
    };

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [stdenv.cc.cc.lib];
    propagatedBuildInputs =
      if slim
      then slimDeps
      else fullDeps;
    # onnxruntime's library comes from the python package at runtime.
    autoPatchelfIgnoreMissingDeps = ["libonnxruntime.so"];

    meta = {
      description = "Context compression layer for AI agents";
      homepage = "https://headroom-docs.vercel.app/docs";
      license = lib.licenses.asl20;
      mainProgram = "headroom";
      platforms = ["x86_64-linux"];
    };
  }
