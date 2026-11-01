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
  autoPatchelfHook,
  stdenv,
  python313Packages,
  slim ? false,
}: let
  py = python313Packages;
  version = "0.40.0";

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
  # reports, otel, evals, html, spreadsheet.
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
      url = "https://files.pythonhosted.org/packages/03/1c/383f4a2d33ad18d40869037ca6221e1db24bc4da5e92befe70793220b138/headroom_ai-${version}-cp310-abi3-manylinux_2_28_x86_64.whl";
      hash = "sha256-SbbYoByOzrW56aZ1cg7V5Msk5GcoJkJlOqx/L9j69H8=";
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
