import * as vscode from 'vscode';
import { settings } from './config';
import { log } from './logging';
export function createStatusBarItem(): vscode.StatusBarItem {
    let statusBar = vscode.window.createStatusBarItem(
        vscode.StatusBarAlignment.Right,
        100
    );
    statusBar.text = "Shell Command";
    statusBar.command = "shellbook.quickPickCommand";
    statusBar.show();
    return statusBar;
}

export const ADD_COMMAND = "Add Custom Command";

export function createQuickPick() {
    const quickPick = vscode.window.createQuickPick();

    quickPick.onDidChangeSelection((selection) => {
        if (selection[0].label === ADD_COMMAND) {
            vscode.commands.executeCommand("workbench.action.openSettings", `@id:shellbook.customCommands @ext:cherryamme.shellbook`);
        } else {
            log.appendLine(`Selected: ${selection[0].label}`);
            const terminal = vscode.window.activeTerminal || vscode.window.createTerminal();
            terminal.show();
            const picked: boolean = selection[0].picked === true;
            terminal.sendText(`${selection[0].description}`, picked);
        }
        quickPick.hide();
    });

    return quickPick;
}

export async function sendToTerminal(uri: vscode.Uri, range: vscode.Range) {
    const document = await vscode.workspace.openTextDocument(uri);
    const codeBlock = "(" + document.getText(range) + "\n)";

    const terminal = vscode.window.activeTerminal || vscode.window.createTerminal();
    log.appendLine(`\nSending to terminal: ${codeBlock}`);
    terminal.show();
    terminal.sendText(codeBlock);
}

export async function sendToQsub(uri: vscode.Uri, range: vscode.Range, firstWord: string) {
    const document = await vscode.workspace.openTextDocument(uri);
    const code = document.getText(range);

    // Send the code chunk to the terminal using echo command
    const terminal = vscode.window.activeTerminal || vscode.window.createTerminal();
    log.appendLine(`\nqsub Sending to terminal: ${code}`);
    terminal.show();
    let command = settings.qsubConfig.toString().replace('${code}', code.toString());
    command = command.replace('${title}', firstWord);
    terminal.sendText(`${command}`);
}

export async function iterToTerminal(uri: vscode.Uri, range: vscode.Range, firstWord: string) {
    const document = await vscode.workspace.openTextDocument(uri);
    const code = document.getText(range);
    const input = await vscode.window.showInputBox({ prompt: 'Enter iter body to run code chunk; eg: i={1..10} / i=1 3 4 5\n', ignoreFocusOut: true, placeHolder: 'i={1..10}' });
    if (!input) {
        return;
    }
    // 使用正则表达式验证输入格式是否为 xx=xxxx
    const regex = /^(\w+)\s*=\s*(.+)$/;
    const match = input.match(regex);

    if (!match) {
        vscode.window.showErrorMessage('Invalid format! Input must be in the format iter=iter_range.');
        return;
    }
    // 提取变量名和值，去除空格
    const variableName = match[1].trim();
    const variableValue = match[2].trim();
    const modifiedCode = `(# Iter code: ${input}\nfor ${variableName} in ${variableValue};do\n ${code}\ndone\n)`;
    // 插入用户输入到原文件中
    const edit = new vscode.WorkspaceEdit();
    const position = new vscode.Position(range.start.line + 1, 0); // 在选定范围下方一行的起始位置插入
    edit.insert(uri, position, `# Iter: ${input}\n`);

    await vscode.workspace.applyEdit(edit);
    const terminal = vscode.window.activeTerminal || vscode.window.createTerminal();
    terminal.show();
    terminal.sendText(modifiedCode);
}



export async function iterFile(uri: vscode.Uri, range: vscode.Range, firstWord: string) {
    const document = await vscode.workspace.openTextDocument(uri);
    const code = document.getText(range);
    const filePath = await vscode.window.showInputBox({ prompt: 'Enter the configfile path to iterate over', ignoreFocusOut: true, placeHolder: 'configfile: /path/to/file'});
    if (!filePath) {
        return;
    }

    const fileUri = vscode.Uri.file(filePath);
    const document2 = await vscode.workspace.openTextDocument(fileUri);
    await vscode.window.showTextDocument(document2, vscode.ViewColumn.Beside);


    // Step 3: Prompt for column name
    const columnName = await vscode.window.showInputBox({
        prompt: 'Enter the column name to iterate over, variable in codechunk to iter (use tab or blank)',
        ignoreFocusOut: true,
        placeHolder: 'column1 column2 column3',
    });


    if (!columnName) {
        vscode.window.showErrorMessage('Column name is required');
        return;
    }
    // Replace commas with spaces, split by spaces, and filter out empty strings
    const variablesArray = columnName.replace(/,/g, ' ').split(/\s+/).map(v => v.trim()).filter(v => v !== '');

    // Join the array back into a space-separated string for use in the shell script
    const variables = variablesArray.join(' ');

    const modifiedCode = `(# Iterfile: ${filePath}\n while read ${variables} _ ;do\n ${code}\ndone < ${filePath}\n)`;

    // 插入用户输入到原文件中
    const edit = new vscode.WorkspaceEdit();
    const position = new vscode.Position(range.start.line + 1, 0); // 在选定范围下方一行的起始位置插入
    edit.insert(uri, position, `# Iterfile: ${filePath}\t Column: ${variables}\n`);
    await vscode.workspace.applyEdit(edit);

    const terminal = vscode.window.activeTerminal || vscode.window.createTerminal();
    terminal.show();
    terminal.sendText(modifiedCode);
}
