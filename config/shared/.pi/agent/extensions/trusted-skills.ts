import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const home = homedir();
const trustedSources = [
  join(home, ".dotfiles/config/shared/skills"),
  join(home, ".dotfiles-more-nixos-opts/skills"),
];

export default function (pi: ExtensionAPI) {
  pi.on("resources_discover", () => ({
    skillPaths: trustedSources.filter((path) => existsSync(path)),
  }));
}
