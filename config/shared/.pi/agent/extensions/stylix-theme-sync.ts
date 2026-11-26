import { readFile } from "node:fs/promises";
import { join } from "node:path";
import {
	getAgentDir,
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const THEME_NAME = "stylix";
const MIN_SYNC_INTERVAL_MS = 30 * 60 * 1000;
const MAX_SYNC_INTERVAL_MS = 60 * 60 * 1000;
const themePath = join(getAgentDir(), "themes", `${THEME_NAME}.json`);
const isUnixLike = process.platform !== "win32";

function randomSyncInterval(): number {
	return (
		MIN_SYNC_INTERVAL_MS +
		Math.floor(Math.random() * (MAX_SYNC_INTERVAL_MS - MIN_SYNC_INTERVAL_MS + 1))
	);
}

export default function (pi: ExtensionAPI) {
	let syncTimer: ReturnType<typeof setTimeout> | undefined;
	let stopped = false;
	let syncing = false;
	let lastThemeSource: string | undefined;

	async function syncTheme(ctx: ExtensionContext): Promise<void> {
		if (stopped || syncing || ctx.mode !== "tui") return;

		syncing = true;
		try {
			const source = await readFile(themePath, "utf8");
			if (stopped || source === lastThemeSource) return;
			lastThemeSource = source;

			// Do not override a theme selected manually after Pi started.
			if (ctx.ui.theme.name !== THEME_NAME) return;

			const result = ctx.ui.setTheme(THEME_NAME);
			if (!result.success) {
				ctx.ui.notify(`Could not sync Stylix theme: ${result.error}`, "warning");
			}
		} catch {
			// Dotfile updates and Home Manager activations can temporarily replace
			// the file. Keep the current theme and retry at the next interval.
		} finally {
			syncing = false;
		}
	}

	function scheduleNextSync(ctx: ExtensionContext): void {
		if (stopped) return;

		syncTimer = setTimeout(async () => {
			await syncTheme(ctx);
			scheduleNextSync(ctx);
		}, randomSyncInterval());
		syncTimer.unref();
	}

	pi.on("session_start", async (_event, ctx) => {
		// NixOS supplies a generated theme; other Unix-like systems use the
		// checked-in file. Both are resolved through Pi's portable agent dir.
		if (!isUnixLike || ctx.mode !== "tui") return;

		stopped = false;
		await syncTheme(ctx);
		scheduleNextSync(ctx);
	});

	pi.on("session_shutdown", () => {
		stopped = true;
		if (syncTimer) clearTimeout(syncTimer);
		syncTimer = undefined;
	});
}
