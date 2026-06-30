using Godot;
using System;
public partial class BBCodeConverter : Node
{
    [Export] TextEdit linkedInput;
    [Export] RichTextLabel linkedOutput;
    string EncaseWith(string text, string encase, bool inverse = false)
    {
        if (inverse)
            return $"[/{encase}]{text}[{encase}]";
        return $"[{encase}]{text}[/{encase}]";
    }
    bool WithinTag(int index, string text, string element)
    {
        string openTag = $"[{element}]";
        string closeTag = $"[/{element}]";
        for (int i = index - 1; i >= 0; i--)
        {
            if (text[i] != ']')
                continue;
            int closeStart = i - closeTag.Length + 1;
            if (closeStart >= 0 && text.Substring(closeStart, closeTag.Length) == closeTag)
                return false;
            int openStart = i - openTag.Length + 1;
            if (openStart >= 0 && text.Substring(openStart, openTag.Length) == openTag)
                return true;
        }
        return false;
    }
    void EncaseSelectedWith(string encase)
    {
        int selStart = linkedInput.GetSelectionOriginColumn();
        string fullText = linkedInput.Text;
        if (linkedInput.HasSelection())
        {
            string originalSelection = linkedInput.GetSelectedText();
            int selEnd = selStart + originalSelection.Length;

            string openTag = $"[{encase}]";
            string closeTag = $"[/{encase}]";

            // Case: selection itself starts and ends with the tag pair -> strip them
            if (originalSelection.StartsWith(openTag) && originalSelection.EndsWith(closeTag)
                && originalSelection.Length >= openTag.Length + closeTag.Length)
            {
                string stripped = originalSelection.Substring(
                    openTag.Length,
                    originalSelection.Length - openTag.Length - closeTag.Length);
                linkedInput.InsertTextAtCaret(stripped);
                return;
            }

            // Case: tags sit just outside the selection (adjacent, not selected) -> strip them
            bool hasOpenBefore = selStart >= openTag.Length
                && fullText.Substring(selStart - openTag.Length, openTag.Length) == openTag;
            bool hasCloseAfter = selEnd + closeTag.Length <= fullText.Length
                && fullText.Substring(selEnd, closeTag.Length) == closeTag;
            if (hasOpenBefore && hasCloseAfter)
            {
                string newText = fullText.Remove(selEnd, closeTag.Length)
                                          .Remove(selStart - openTag.Length, openTag.Length);
                linkedInput.Text = newText;
                TransferText();
                return;
            }

            // Case: tag pair exists INSIDE the selection -> strip the inner pair, wrap the whole selection
            if (originalSelection.Contains(openTag) && originalSelection.Contains(closeTag))
            {
                string innerStripped = originalSelection.Replace(openTag, "").Replace(closeTag, "");
                linkedInput.InsertTextAtCaret(EncaseWith(innerStripped, encase));
                return;
            }

            // Fallback: walk backward from selection start to see if we're inside an enclosing tag
            bool withinTag = WithinTag(selStart, fullText, encase);
            string modifiedText = EncaseWith(originalSelection, encase, withinTag);
            linkedInput.InsertTextAtCaret(modifiedText);
        }
        else
        {

            bool withinTag = WithinTag(selStart, fullText, encase);
            string insertText = EncaseWith("", encase, withinTag);
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