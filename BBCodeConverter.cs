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

    /// <summary>
    /// Keeps the output preview up to date as the user edits the input.
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
        int selStart = hasSelection ? linkedInput.GetSelectionFromColumn() : linkedInput.GetCaretColumn();
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
            linkedInput.SetCaretColumn(edit.SelectionStart);
        }
        else
        {
            linkedInput.Select(0, edit.SelectionStart, 0, edit.SelectionEnd);
        }
    }

    /// <summary>
    /// Keeps the rendered preview in sync with the raw BBCode input.
    /// </summary>
    void TransferText()
    {
        linkedOutput.Text = linkedInput.Text;
    }
}