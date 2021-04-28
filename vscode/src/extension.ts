"use strict";

import * as vscode from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
} from "vscode-languageclient/node";
import * as net from "net";
import * as child_process from "child_process";
import { PRIORITY_BELOW_NORMAL } from "node:constants";

export function makeLanguageClient(): LanguageClient {
  let client: LanguageClient;

  const serverOptions: ServerOptions = async () => {
    const ruby = new Promise<
      [
        child_process.ChildProcessWithoutNullStreams,
        { host: string; port: number; pid: number }
      ]
    >((resolve, reject) => {
      const workspace = vscode.workspace.workspaceFolders;
      const opts =
        workspace && workspace[0] ? { cwd: workspace[0].uri.fsPath } : {};
      client.info(`path: ${opts["cwd"]}`);

      const ruby = child_process.spawn(
        "bundle",
        ["exec", "exe/typeprof", "--lsp"],
        opts
      );
      client.info("Invoking bundle exec exe/typeprof --lsp");

      let buffer = "";
      ruby.stdout.on("data", (data) => {
        buffer += data;
        try {
          const json = JSON.parse(data);
          resolve([ruby, json]);
        } catch (err) {}
      });

      let err = "";
      ruby.stderr.on("data", (data) => {
        err += data;
        while (true) {
          const i = err.indexOf("\n");
          if (i < 0) break;
          client.info("bundle stderr: " + err.slice(0, i));
          err = err.slice(i + 1);
        }
      });

      ruby.on("exit", (code) => reject(`error code ${code}`));
    });

    const [child, { host, port }] = await ruby;
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
      fileEvents: vscode.workspace.createFileSystemWatcher(
        "{**/*.rb,**/*.rbs}"
      ),
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
