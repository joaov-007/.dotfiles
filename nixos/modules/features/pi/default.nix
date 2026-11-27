{moduleWithSystem, ...}: {
  flake.modules.homeManager.pi = moduleWithSystem ({
    pkgs,
    self',
    ...
  }: {
    config,
    lib,
    symlinkRoot,
    ...
  }: let
    colors = config.lib.stylix.colors;
    hex = name: "#${colors.${name}}";

    theme = {
      "$schema" = "https://pi.dev/schemas/theme.schema.json";
      name = "stylix";
      appearance = config.stylix.polarity;
      vars = {
        text = hex "base05";
        muted = hex "base04";
        dim = hex "base03";
        violet = hex "base0E";
        blue = hex "base0D";
        cyan = hex "base0C";
        green = hex "base0B";
        red = hex "base0F";
        yellow = hex "base0A";
        selectedBg = hex "base02";
      };
      colors = {
        accent = "violet";
        border = "dim";
        borderAccent = "violet";
        borderMuted = "selectedBg";
        success = "green";
        error = "red";
        warning = "yellow";
        muted = "muted";
        dim = "dim";
        text = "text";
        thinkingText = "muted";
        scrollbarTrack = "dim";
        scrollbarThumb = "muted";
        selectedBg = "selectedBg";
        searchMatchBg = "selectedBg";
        searchMatchText = "text";
        userMessageBg = "selectedBg";
        userMessageText = "text";
        customMessageBg = "selectedBg";
        customMessageText = "text";
        customMessageLabel = "violet";
        toolPendingBg = "selectedBg";
        toolSuccessBg = "selectedBg";
        toolErrorBg = "selectedBg";
        toolTitle = "text";
        toolOutput = "muted";
        mdHeading = "yellow";
        mdLink = "blue";
        mdLinkUrl = "muted";
        mdCode = "violet";
        mdCodeBlock = "green";
        mdCodeBlockBorder = "muted";
        mdQuote = "muted";
        mdQuoteBorder = "muted";
        mdHr = "muted";
        mdListBullet = "violet";
        toolDiffAdded = "green";
        toolDiffRemoved = "red";
        toolDiffContext = "muted";
        syntaxComment = "muted";
        syntaxKeyword = "violet";
        syntaxFunction = "blue";
        syntaxVariable = "text";
        syntaxString = "green";
        syntaxNumber = "yellow";
        syntaxType = "cyan";
        syntaxOperator = "blue";
        syntaxPunctuation = "muted";
        thinkingOff = "dim";
        thinkingMinimal = "muted";
        thinkingLow = "blue";
        thinkingMedium = "cyan";
        thinkingHigh = "violet";
        thinkingXhigh = "red";
        thinkingMax = "yellow";
        bashMode = "green";
      };
      export = {
        pageBg = hex "base00";
        cardBg = hex "base01";
        infoBg = hex "base02";
      };
    };

    trustedSkillLoader = pkgs.writeText "pi-trusted-skills.ts" ''
      import { existsSync } from "node:fs";
      import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

      const trustedSources: string[] = ${builtins.toJSON config.programs.pi.trustedSkillSources};

      export default function (pi: ExtensionAPI) {
        pi.on("resources_discover", () => ({
          skillPaths: trustedSources.filter((path) => existsSync(path)),
        }));
      }
    '';

    fffExtension = "${self'.packages.pi-fff}/lib/node_modules/@ff-labs/pi-fff/src/index.ts";

    portableSettings = builtins.fromJSON (
      builtins.readFile ../../../../config/shared/.pi/agent/settings.json
    );

    portablePackages = portableSettings.packages or [ ];
    nixPackages = builtins.filter (pkg: pkg != "npm:@ff-labs/pi-fff@0.11.0") portablePackages;
  in {
    options.programs.pi.trustedSkillSources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${config.home.homeDirectory}/.dotfiles/config/shared/skills"
        "${config.home.homeDirectory}/.dotfiles-more-nixos-opts/skills"
      ];
      description = "Trusted directories recursively scanned for Pi skills at startup and reload.";
    };

    config = {
      home.packages = [pkgs.pi-coding-agent pkgs.nodejs];

      # Reuse the portable defaults, but load plugins from the Nix store rather
      # than asking Pi to download npm packages into its mutable agent directory.
      home.file.".pi/agent/settings.json".text = builtins.toJSON (
        (builtins.removeAttrs portableSettings ["packages"])
        // {
          packages = nixPackages;
          extensions = [
            fffExtension
            "${trustedSkillLoader}"
          ];
        }
      );

      home.file.".pi/agent/mcp.json".source =
        config.lib.file.mkOutOfStoreSymlink
        "${symlinkRoot}/config/shared/.pi/agent/mcp.json";

      home.file.".pi/agent/models.json".source =
        config.lib.file.mkOutOfStoreSymlink
        "${symlinkRoot}/config/shared/.pi/agent/models.json";

      home.file.".pi/agent/pi-fff.json".source =
        config.lib.file.mkOutOfStoreSymlink
        "${symlinkRoot}/config/shared/.pi/agent/pi-fff.json";

      home.file.".pi/agent/extensions/stylix-theme-sync.ts".source =
        config.lib.file.mkOutOfStoreSymlink
        "${symlinkRoot}/config/shared/.pi/agent/extensions/stylix-theme-sync.ts";

      home.file.".pi/agent/themes/stylix.json".text = builtins.toJSON theme;
    };
  });
}
