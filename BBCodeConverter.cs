using Godot;
using System;

public partial class BBCodeConverter : Node
{
    [Export] TextEdit linkedInput;
    [Export] RichTextLabel linkedOutput;

    string EncaseWith(string text, string encase)
    {
        return $"[{encase}]{text}[/{encase}]";
    }

    void EncaseSelectedWith(string encase)
    {
        if (linkedInput.HasSelection())
        {
            string originalSelection = linkedInput.GetSelectedText();
            string modifiedText = EncaseWith(originalSelection, encase);
            linkedInput.InsertTextAtCaret(modifiedText);
        }
        else
        {
            string insertText = EncaseWith("", encase);
            linkedInput.InsertTextAtCaret(insertText);
        }
    }

    void TransferText()
    {
        string text = linkedInput.Text;

        linkedOutput.Text = text;
    }

    public override void _Ready()
    {
        TransferText();
    }

    public void MakeBold()
    {
        EncaseSelectedWith("b");
    }

    public void TextUpdated()
    {
        TransferText();
    }
}
