{moduleWithSystem, ...}: {
  flake.modules.homeManager.pi = moduleWithSystem ({
    pkgs,
    self',
    ...
  }: {
    config,
    lib,
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
      home.packages = [pkgs.pi-coding-agent];

      home.file.".pi/agent/settings.json".text = builtins.toJSON {
        defaultProvider = "opencode-go";
        defaultModel = "kimi-k3.1-pro";
        theme = "stylix";
        extensions = [
          fffExtension
          "${trustedSkillLoader}"
        ];
      };

      home.file.".pi/agent/pi-fff.json".text = builtins.toJSON {
        mode = "tools-and-ui";
      };

      home.file.".pi/agent/themes/stylix.json".text = builtins.toJSON theme;
    };
  });
}
