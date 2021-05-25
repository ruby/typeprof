"use strict";

import * as vscode from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
} from "vscode-languageclient/node";
import * as net from "net";
import * as child_process from "child_process";
import { existsSync } from "fs";

export function makeLanguageClient(): LanguageClient {
  let client: LanguageClient;

  const invokeTypeProf = (): child_process.ChildProcessWithoutNullStreams => {
    const workspace = vscode.workspace.workspaceFolders;
    const cwd = workspace && workspace[0] ? workspace[0].uri.fsPath : undefined;
    const opts = cwd ? { cwd } : {};
    client.info(`path: ${opts["cwd"]}`);

    let cmd: string;
    let cmd_args: string[];
    if (existsSync(`${cwd}/typeprof-lsp`)) {
      cmd = "./typeprof-lsp";
      cmd_args = [];
    } else {
      cmd = "bundle";
      cmd_args = ["exec", "typeprof", "--lsp"];
    }
    const typeprof = child_process.spawn(cmd, cmd_args, opts);
    client.info(`Invoking ${cmd} ${cmd_args.join(" ")}`);
    return typeprof;
  };

  const serverOptions: ServerOptions = async () => {
    const typeprof = new Promise<
      [
        child_process.ChildProcessWithoutNullStreams,
        { host: string; port: number; pid: number }
      ]
    >((resolve, reject) => {
      const typeprof = invokeTypeProf();

      let buffer = "";
      typeprof.stdout.on("data", (data) => {
        buffer += data;
        try {
          const json = JSON.parse(data);
          resolve([typeprof, json]);
        } catch (err) {}
      });

      let err = "";
      typeprof.stderr.on("data", (data) => {
        err += data;
        while (true) {
          const i = err.indexOf("\n");
          if (i < 0) break;
          client.info("bundle stderr: " + err.slice(0, i));
          err = err.slice(i + 1);
        }
      });

      typeprof.on("exit", (code) => reject(`error code ${code}`));
    });

    const [child, { host, port }] = await typeprof;
    const socket: net.Socket = net.createConnection(port, host);
    socket.on("close", (_had_error) => child.kill("SIGINT"));

    return {
      reader: socket,
      writer: socket,
    };
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [
      { scheme: "file", language: "ruby" },
      { scheme: "file", language: "rbs" },
    ],
    synchronize: {
      fileEvents:
        vscode.workspace.createFileSystemWatcher("{**/*.rb,**/*.rbs}"),
    },
  };

  client = new LanguageClient("Ruby TypeProf", serverOptions, clientOptions);

  const showStatus = (msg: string) =>
    vscode.window.setStatusBarMessage(msg, 3000);

  showStatus("Starting Ruby TypeProf...");

  client
    .onReady()
    .then(() => {
      showStatus("Ruby TypeProf is running");
    })
    .catch((e: any) => {
      showStatus(`Failed to start Ruby TypeProf: ${e}`);
    });

  return client;
}

let client: LanguageClient;

export function activate(context: vscode.ExtensionContext) {
  client = makeLanguageClient();
  client.start();
}

export function deactivate() {
  if (client) client.stop();
}
