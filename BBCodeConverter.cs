using Godot;
using System;

public partial class BBCodeConverter : Node
{
    [Export] TextEdit linkedInput;
    [Export] RichTextLabel linkedOutput;

    readonly BBCodeTagEditor tagEditor = new BBCodeTagEditor();

    /// <summary>
    /// Initializes the output preview to match the input when this node starts.
    /// </summary>
    public override void _Ready()
    {
        TransferText();
    }

    /// <summary>
    /// Toggles bold formatting on the current selection.
    /// </summary>
    public void ToggleBold()
    {
        EncaseSelectedWith("b");
    }

    /// <summary>
    /// Toggles bold formatting on the current selection.
    /// </summary>
    public void ToggleItalic()
    {
        EncaseSelectedWith("i");
    }

    public void ToggleUnderlined()
    {
        EncaseSelectedWith("u");
    }

    public void ToggleStrikethrough()
    {
        EncaseSelectedWith("s");
    }

    public void ToggleCenter()
    {
        EncaseSelectedWith("center");
    }

    public void ToggleLeft()
    {
        EncaseSelectedWith("left");
    }

    public void ToggleRight()
    {
        EncaseSelectedWith("right");
    }

    public void ToggleFill()
    {
        EncaseSelectedWith("fill");
    }

    public void ToggleList()
    {
        bool hasSelection = linkedInput.HasSelection();
        int selStart = hasSelection
            ? tagEditor.LineColToOffset(linkedInput.Text, linkedInput.GetSelectionFromLine(), linkedInput.GetSelectionFromColumn())
            : tagEditor.LineColToOffset(linkedInput.Text, linkedInput.GetCaretLine(), linkedInput.GetCaretColumn());
        int selEnd = hasSelection
            ? tagEditor.LineColToOffset(linkedInput.Text, linkedInput.GetSelectionToLine(), linkedInput.GetSelectionToColumn())
            : selStart;
        TagEditResult edit = tagEditor.ToggleList(linkedInput.Text, hasSelection, selStart, selEnd);
        ApplyEdit(edit);
        TransferText();
    }

    /// <summary>
    /// Entry point for signals. Keeps the output preview up to date as the user edits the input.
    /// </summary>
    public void TextUpdated()
    {
        TransferText();
    }

    /// <summary>
    /// Toggles the given BBCode tag on the current selection and refreshes the preview.
    /// </summary>
    /// <param name="encase">The tag name to apply or remove, e.g. "b" or "i".</param>
    void EncaseSelectedWith(string encase)
    {
        bool hasSelection = linkedInput.HasSelection();
        int selStart = hasSelection
            ? LineColToOffset(linkedInput.GetSelectionFromLine(), linkedInput.GetSelectionFromColumn())
            : LineColToOffset(linkedInput.GetCaretLine(), linkedInput.GetCaretColumn());
        string selectedText = hasSelection ? linkedInput.GetSelectedText() : "";
        TagEditResult edit = tagEditor.ToggleTag(linkedInput.Text, hasSelection, selStart, selectedText, encase);
        ApplyEdit(edit);
        TransferText();
    }

    /// <summary>
    /// Applies a computed text edit and selection to the input control. The only
    /// place in this class that mutates <see cref="linkedInput"/> directly.
    /// </summary>
    void ApplyEdit(TagEditResult edit)
    {
        linkedInput.Text = edit.NewText;
        if (edit.SelectionStart == edit.SelectionEnd)
        {
            (int line, int column) = OffsetToLineCol(edit.NewText, edit.SelectionStart);
            linkedInput.SetCaretLine(line);
            linkedInput.SetCaretColumn(column);
        }
        else
        {
            (int fromLine, int fromColumn) = OffsetToLineCol(edit.NewText, edit.SelectionStart);
            (int toLine, int toColumn) = OffsetToLineCol(edit.NewText, edit.SelectionEnd);
            linkedInput.Select(fromLine, fromColumn, toLine, toColumn);
        }
    }

    int LineColToOffset(int line, int column)
    {
        int offset = 0;
        for (int i = 0; i < line; i++)
        {
            offset += linkedInput.GetLine(i).Length + 1; // +1 for the newline
        }
        return offset + column;
    }

    (int line, int column) OffsetToLineCol(string text, int offset)
    {
        int line = 0;
        int column = offset;
        int searchPos = 0;
        while (true)
        {
            int newlineIndex = text.IndexOf('\n', searchPos);
            if (newlineIndex == -1 || newlineIndex >= offset)
            {
                break;
            }
            line++;
            column = offset - (newlineIndex + 1);
            searchPos = newlineIndex + 1;
        }
        return (line, column);
    }

    /// <summary>
    /// Keeps the rendered preview in sync with the raw BBCode input.
    /// </summary>
    void TransferText()
    {
        linkedOutput.Text = linkedInput.Text;
    }
}