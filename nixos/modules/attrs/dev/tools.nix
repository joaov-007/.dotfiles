{
  self,
  moduleWithSystem,
  ...
}: {
  flake.modules.nixos.developmentTools = moduleWithSystem ({pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      devenv

      # Ansible (nixpkgs exposes ansible-core as `ansible`)
      ansible
      ansible-lint
      ansible-navigator
      ansible-language-server
      molecule
      python3Packages.molecule-plugins
      sshpass
      wget

      # Python helpers used by Ansible/Jinja and modules
      python3Packages.jmespath
      python3Packages.netaddr
      python3Packages.passlib

      # Search & data
      ripgrep
      fd
      jq
      yq-go

      # Docs
      pandoc

      # Formatters
      nixfmt-rfc-style
      shfmt
      prettier
      ruff
      taplo

      # Linters
      shellcheck
      statix
      deadnix
      markdownlint-cli
      yamllint
      codespell
      actionlint
      hadolint
      treefmt

      # Secrets / passwords
      bitwarden-cli
      rbw
    ];
  });

  flake.modules.homeManager.developmentTools = moduleWithSystem ({...}: {
    imports = with self.modules.homeManager; [
      git
      nvim
      pi
    ];

    programs.lazygit = {
      enable = true;
      enableBashIntegration = true;
    };
    programs.devenv = {
      enable = true;
      enableBashIntegration = true;
    };
    programs.herdr.enable = true;
  });
}
