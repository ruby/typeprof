import * as assert from 'assert';
import * as path from 'path';
import * as cp from 'child_process';
import * as fs from 'fs';

import * as vscode from 'vscode';

const projectRoot = path.join(__dirname, '..', '..', '..', '..');
const simpleProgramPath = path.join(projectRoot, 'src', 'test', 'simpleProgram');

suite('completion', () => {
	setup(async () => {
		await vscode.commands.executeCommand('vscode.openFolder', vscode.Uri.file(simpleProgramPath));
		cp.execSync('bundle install; rbs collection install', { cwd: simpleProgramPath });
	});

	teardown(() => {
		cleanUpFiles();
	});

	test('liam.', async () => {
		const doc = await openTargetFile(path.join(simpleProgramPath, 'student.rb'));
		const list = (await vscode.commands.executeCommand('vscode.executeCompletionItemProvider', doc.uri, new vscode.Position(13, 18))) as vscode.CompletionList;
		const study = list.items.filter(item => item.label === 'study');
		assert.strictEqual(study.length, 1);
		assert.strictEqual(study[0].kind, vscode.CompletionItemKind.Method);
		const singleton_class = list.items.filter(item => item.label === 'singleton_class');
		assert.strictEqual(singleton_class[0].kind, vscode.CompletionItemKind.Method);
		assert.ok(singleton_class.length === 1);
	});
});

suite('diagnostics', () => {
	setup(async () => {
		await vscode.commands.executeCommand('vscode.openFolder', vscode.Uri.file(simpleProgramPath));
		cp.execSync('bundle install; rbs collection install', { cwd: simpleProgramPath });
	});

	teardown(() => {
		cleanUpFiles();
	});

	test('wrong number of arguments (given 0, expected 1)', async () => {
		const doc = await openTargetFile(path.join(simpleProgramPath, 'student.rb'));
		const diagnostics = vscode.languages.getDiagnostics(doc.uri);
		const actual = diagnostics.filter(d => d.message === '[error] wrong number of arguments (given 0, expected 1)');
		assert.ok(actual.length === 1);
		assert.strictEqual(actual[0].severity, vscode.DiagnosticSeverity.Error);
		assert.deepStrictEqual(actual[0].range, new vscode.Range(new vscode.Position(13, 0), new vscode.Position(13, 10)));
	});

	test('wrong number of arguments (given 2, expected 1)', async () => {
		const doc = await openTargetFile(path.join(simpleProgramPath, 'student.rb'));
		const diagnostics = vscode.languages.getDiagnostics(doc.uri);
		const actual = diagnostics.filter(d => d.message === '[error] wrong number of arguments (given 2, expected 1)');
		assert.ok(actual.length === 1);
		assert.strictEqual(actual[0].severity, vscode.DiagnosticSeverity.Error);
		assert.deepStrictEqual(actual[0].range, new vscode.Range(new vscode.Position(14, 0), new vscode.Position(14, 29)));
	});

	test('failed to resolve overload: Integer#+', async () => {
		const doc = await openTargetFile(path.join(simpleProgramPath, 'increment.rb'));
		const diagnostics = vscode.languages.getDiagnostics(doc.uri);
		const actual = diagnostics.filter(d => d.message === '[error] failed to resolve overload: Integer#+');
		// TODO: fix this length to 1
		assert.ok(actual.length === 2);
		assert.strictEqual(actual[0].severity, vscode.DiagnosticSeverity.Error);
		assert.deepStrictEqual(actual[0].range, new vscode.Range(new vscode.Position(6, 4), new vscode.Position(6, 17)));
	});
});

suite('go to definitions', () => {
	setup(async () => {
		await vscode.commands.executeCommand('vscode.openFolder', vscode.Uri.file(simpleProgramPath));
		cp.execSync('bundle install; rbs collection install', { cwd: simpleProgramPath });
	});

	teardown(() => {
		cleanUpFiles();
	});

	test('go to initialize method', async () => {
		const doc = await openTargetFile(path.join(simpleProgramPath, 'student.rb'));
		const loc = (await vscode.commands.executeCommand('vscode.executeDefinitionProvider', doc.uri, new vscode.Position(10, 16))) as vscode.Location[];
		console.log(loc.length.toString());
		assert.ok(loc && loc.length === 1);
		assert.deepStrictEqual(loc[0].range, new vscode.Range(new vscode.Position(1, 2), new vscode.Position(3, 5)));
	});

	test('go to study method', async () => {
		const doc = await openTargetFile(path.join(simpleProgramPath, 'student.rb'));
		const loc = (await vscode.commands.executeCommand('vscode.executeDefinitionProvider', doc.uri, new vscode.Position(11, 5))) as vscode.Location[];
		assert.ok(loc && loc.length === 1);
		assert.deepStrictEqual(loc[0].range, new vscode.Range(new vscode.Position(5, 2), new vscode.Position(8, 5)));
	});
});

async function openTargetFile(path: string) {
	const doc = await vscode.workspace.openTextDocument(path);
	await vscode.window.showTextDocument(doc);
	await new Promise(res => setTimeout(res, 5000));
	return doc;
}

function cleanUpFiles() {
	fs.unlinkSync(path.join(simpleProgramPath, 'rbs_collection.lock.yaml'));
	fs.unlinkSync(path.join(simpleProgramPath, 'Gemfile.lock'));
	fs.rmdirSync(path.join(simpleProgramPath, '.gem_rbs_collection'));
}
