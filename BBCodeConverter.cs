using Godot;
using System;

/// <summary>
/// Godot uses BBCode for Rich Text in text fields.
/// This class provides the functions to add and manage the relevant tags.
/// </summary>
public partial class BBCodeConverter : Node
{
    [Export] TextEdit linkedInput;
    [Export] RichTextLabel linkedOutput;

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
    /// Toggles italic formatting on the current selection.
    /// </summary>
    public void ToggleItalic()
    {
        EncaseSelectedWith("i");
    }

    /// <summary>
    /// Toggles underline formatting on the current selection.
    /// </summary>
    public void ToggleUnderlined()
    {
        EncaseSelectedWith("u");
    }

    /// <summary>
    /// Toggles strikethrough formatting on the current selection.
    /// </summary>
    public void ToggleStrikethrough()
    {
        EncaseSelectedWith("s");
    }

    /// <summary>
    /// Toggles center alignment on the current selection.
    /// </summary>
    public void ToggleCenter()
    {
        EncaseSelectedWith("center");
    }

    /// <summary>
    /// Toggles left alignment on the current selection.
    /// </summary>
    public void ToggleLeft()
    {
        EncaseSelectedWith("left");
    }

    /// <summary>
    /// Toggles right alignment on the current selection.
    /// </summary>
    public void ToggleRight()
    {
        EncaseSelectedWith("right");
    }

    /// <summary>
    /// Toggles fill alignment on the current selection.
    /// </summary>
    public void ToggleFill()
    {
        EncaseSelectedWith("fill");
    }

    /// <summary>
    /// Undoes the last action.
    /// </summary>
    public void Undo()
    {
        linkedInput.Undo();
        TransferText();
    }

    /// <summary>
    /// Redoes the last undone action.
    /// </summary>
    public void Redo()
    {
        linkedInput.Redo();
        TransferText();
    }

    /// <summary>
    /// Wraps the current selection into a list layer.
    /// </summary>
    public void AddListLayer()
    {
        bool hasSelection = linkedInput.HasSelection();
        int selStart = hasSelection
            ? BBCodeUtility.IndexFromTextCoordinate(linkedInput.Text, linkedInput.GetSelectionFromLine(), linkedInput.GetSelectionFromColumn())
            : BBCodeUtility.IndexFromTextCoordinate(linkedInput.Text, linkedInput.GetCaretLine(), linkedInput.GetCaretColumn());
        int selEnd = hasSelection
            ? BBCodeUtility.IndexFromTextCoordinate(linkedInput.Text, linkedInput.GetSelectionToLine(), linkedInput.GetSelectionToColumn())
            : selStart;
        TagEditResult edit = BBCodeUtility.AddListLayer(linkedInput.Text, hasSelection, selStart, selEnd);
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
            ? BBCodeUtility.IndexFromTextCoordinate(linkedInput.Text, linkedInput.GetSelectionFromLine(), linkedInput.GetSelectionFromColumn())
            : BBCodeUtility.IndexFromTextCoordinate(linkedInput.Text, linkedInput.GetCaretLine(), linkedInput.GetCaretColumn());
        string selectedText = hasSelection ? linkedInput.GetSelectedText() : "";
        TagEditResult edit = BBCodeUtility.ToggleTag(linkedInput.Text, hasSelection, selStart, selectedText, encase);
        ApplyEdit(edit);
        TransferText();
    }

    /// <summary>
    /// Applies a computed text edit and selection to the input control. The only
    /// place in this class that mutates <see cref="linkedInput"/> directly.
    /// </summary>
    void ApplyEdit(TagEditResult edit)
    {
        (int fromLine, int fromColumn) = BBCodeUtility.TextCoordinateFromIndex(edit.NewText, edit.SelectionStart);
        (int toLine, int toColumn) = BBCodeUtility.TextCoordinateFromIndex(edit.NewText, edit.SelectionEnd);

        linkedInput.BeginComplexOperation();
        linkedInput.SelectAll();
        linkedInput.InsertTextAtCaret(edit.NewText);
        if (edit.SelectionStart == edit.SelectionEnd)
        {
            linkedInput.SetCaretLine(fromLine);
            linkedInput.SetCaretColumn(fromColumn);
        }
        else
        {
            linkedInput.Select(fromLine, fromColumn, toLine, toColumn);
        }
        linkedInput.EndComplexOperation();
    }

    /// <summary>
    /// Keeps the rendered preview in sync with the raw BBCode input.
    /// </summary>
    void TransferText()
    {
        linkedOutput.Text = linkedInput.Text;
    }
}