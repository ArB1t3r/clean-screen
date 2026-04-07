import { closeMainWindow, environment, showHUD, showToast, Toast } from "@raycast/api";
import { spawn } from "node:child_process";
import { constants } from "node:fs";
import { access, mkdir, readdir, stat } from "node:fs/promises";
import { join } from "node:path";

interface ProcessResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

function getHelperPaths() {
  const packagePath = join(environment.assetsPath, "clean-screen-helper");
  const buildPath = join(environment.supportPath, "clean-screen-helper-build");
  const binaryPath = join(buildPath, "release", "CleanScreenHelper");
  return { packagePath, buildPath, binaryPath };
}

async function ensureHelperBuild(packagePath: string, buildPath: string, binaryPath: string): Promise<void> {
  const packageExists = await exists(packagePath);
  if (!packageExists) {
    throw new Error(`Swift helper package not found at ${packagePath}`);
  }

  await mkdir(buildPath, { recursive: true });
  const needsBuild = environment.isDevelopment || (await helperNeedsBuild(packagePath, binaryPath));
  if (!needsBuild) {
    return;
  }

  const buildResult = await runProcess("swift", [
    "build",
    "-c",
    "release",
    "--package-path",
    packagePath,
    "--build-path",
    buildPath,
  ]);

  if (buildResult.exitCode !== 0) {
    throw new Error(
      `Swift build failed: ${buildResult.stderr.trim() || buildResult.stdout.trim() || "Unknown error"}`,
    );
  }
}

async function helperNeedsBuild(packagePath: string, binaryPath: string): Promise<boolean> {
  if (!(await exists(binaryPath))) {
    return true;
  }

  const binaryStats = await stat(binaryPath);
  const newestSourceMtime = await newestHelperSourceMtime(packagePath);
  return newestSourceMtime > binaryStats.mtimeMs;
}

async function newestHelperSourceMtime(rootPath: string): Promise<number> {
  let newestMtime = 0;
  const entries = await readdir(rootPath, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = join(rootPath, entry.name);
    if (entry.isDirectory()) {
      newestMtime = Math.max(newestMtime, await newestHelperSourceMtime(fullPath));
      continue;
    }

    if (entry.name === "Package.swift" || entry.name.endsWith(".swift")) {
      const fileStats = await stat(fullPath);
      newestMtime = Math.max(newestMtime, fileStats.mtimeMs);
    }
  }

  return newestMtime;
}

async function runProcess(command: string, args: string[]): Promise<ProcessResult> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString("utf8");
    });

    child.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString("utf8");
    });

    child.on("error", reject);
    child.on("close", (code) => {
      resolve({
        stdout,
        stderr,
        exitCode: code ?? 1,
      });
    });
  });
}

async function exists(targetPath: string): Promise<boolean> {
  try {
    await access(targetPath, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

export default async function command() {
  try {
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Preparing Clean Screen",
      message: "Building native helper",
    });

    const helperPaths = getHelperPaths();
    await ensureHelperBuild(helperPaths.packagePath, helperPaths.buildPath, helperPaths.binaryPath);

    await closeMainWindow();

    toast.message = "Launching cleaning session";

    const child = spawn(helperPaths.binaryPath, [], {
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
