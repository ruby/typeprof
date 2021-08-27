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

const CONFIGURATION_ROOT_SECTION = "typeprof"

export function makeLanguageClient(): LanguageClient {
  let client: LanguageClient;

  const invokeTypeProf = (): child_process.ChildProcessWithoutNullStreams => {
    const workspace = vscode.workspace.workspaceFolders;
    const configuration = vscode.workspace.getConfiguration(CONFIGURATION_ROOT_SECTION);
    const customServerPath = configuration.get<string | null>("server.path");
    const cwd = workspace && workspace[0] ? workspace[0].uri.fsPath : undefined;
    const opts = cwd ? { cwd } : {};
    client.info(`Workspace path: ${opts["cwd"]}`);

    let cmd: string;
    let cmd_args: string[];
    if (existsSync(`${cwd}/typeprof-lsp`)) {
      cmd = "./typeprof-lsp";
      cmd_args = [];
    } else if (customServerPath) {
      cmd = customServerPath
      cmd_args = ["--lsp"];
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
          client.info(err.slice(0, i));
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
  vscode.commands.registerCommand("jump_to_rbs", (arg0: any, arg1: any, arg2: any, arg3: any) => {
    //vscode.window.showInformationMessage(`hello ${ arg0 } ${ arg1 } ${ arg2 } ${ arg3 }`);
    const uri0 = vscode.Uri.parse(arg0);
    const pos0 = new vscode.Position(arg1.line, arg1.character);
    const uri1 = vscode.Uri.parse(arg2);
    const pos1 = new vscode.Position(arg3.start.line, arg3.start.character);
    const pos2 = new vscode.Position(arg3.end.line, arg3.end.character);
    const range = new vscode.Range(pos1, pos2);
    const loc = new vscode.Location(uri1, range);
    vscode.commands.executeCommand("editor.action.peekLocations", uri0, pos0, [loc], "peek");
  });
  client = makeLanguageClient();
  client.start();
}

export function deactivate() {
  if (client) client.stop();
}
