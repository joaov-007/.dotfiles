{...}: {
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "jaov";
        email = "jaov@example.com";
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      alias = {
        st = "status";
        ci = "commit";
        br = "branch";
        co = "checkout";
        df = "diff";
      };
    };
  };
}
