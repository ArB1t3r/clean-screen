import { closeMainWindow, environment, showHUD, showToast, Toast } from "@raycast/api";
import { constants, accessSync } from "node:fs";
import { join } from "node:path";
import { spawn } from "node:child_process";

function getHelperPath() {
  return join(environment.assetsPath, "CleanScreenHelper.app");
}

export default async function command() {
  const helperPath = getHelperPath();

  try {
    accessSync(helperPath, constants.F_OK);
  } catch {
    await showToast({
      style: Toast.Style.Failure,
      title: "Helper binary missing",
      message: "Run `npm run build:helper` in the extension folder first.",
    });
    return;
  }

  try {
    await closeMainWindow();

    const child = spawn("/usr/bin/open", [helperPath], {
      detached: true,
      stdio: "ignore",
    });

    child.unref();

    await showHUD("Cleaning session started");
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown launch failure";

    await showToast({
      style: Toast.Style.Failure,
      title: "Failed to launch cleaning session",
      message,
    });
  }
}
