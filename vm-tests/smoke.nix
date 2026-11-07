# Smoke test for flakeModules.vmTests itself: one small VM boots, and the
# module's `self` argument reaches node modules. Run it with
# `vm-test smoke`; it never runs in CI.
{
  nodes.machine = {
    self,
    pkgs,
    ...
  }: {
    environment = {
      etc."vm-test-self".text = self.outPath;
      systemPackages = [pkgs.hello];
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target", timeout=300)
    machine.succeed("hello | grep -q 'Hello, world!'")
    machine.succeed("test -s /etc/vm-test-self")
  '';
}
