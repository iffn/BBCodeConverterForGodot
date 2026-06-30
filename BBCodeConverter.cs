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
        RunEncaseLogicOnSelection(encase);
        TransferText();
    }

    void RunEncaseLogicOnSelection(string encase)
    {
        bool hasSelection = linkedInput.HasSelection();
        int selStart = hasSelection ? linkedInput.GetSelectionFromColumn() : linkedInput.GetCaretColumn();
        string fullText = linkedInput.Text;
        string openTag = $"[{encase}]";
        string closeTag = $"[/{encase}]";

        if (!hasSelection)
        {
            bool withinTag = WithinTag(selStart, fullText, encase);
            string insertText = EncaseWith("", encase, withinTag);
            linkedInput.InsertTextAtCaret(insertText);
            string firstTag = withinTag ? closeTag : openTag;
            int caret = selStart + firstTag.Length;
            linkedInput.SetCaretColumn(caret);
            return;
        }

        string originalSelection = linkedInput.GetSelectedText();
        int selEnd = selStart + originalSelection.Length;

        // Case: selection itself starts and ends with the tag pair -> strip them
        if (originalSelection.StartsWith(openTag) && originalSelection.EndsWith(closeTag)
            && originalSelection.Length >= openTag.Length + closeTag.Length)
        {
            string stripped = originalSelection.Substring(
                openTag.Length,
                originalSelection.Length - openTag.Length - closeTag.Length);
            linkedInput.InsertTextAtCaret(stripped); // replaces the current selection
            linkedInput.Select(0, selStart, 0, selStart + stripped.Length);
            return;
        }

        // Case: tags sit just outside the selection (adjacent, not selected) -> strip them
        bool hasOpenBefore = selStart >= openTag.Length
            && fullText.Substring(selStart - openTag.Length, openTag.Length) == openTag;
        bool hasCloseAfter = selEnd + closeTag.Length <= fullText.Length
            && fullText.Substring(selEnd, closeTag.Length) == closeTag;
        if (hasOpenBefore && hasCloseAfter)
        {
            // remove the close tag first (it's after the selection, doesn't shift earlier offsets),
            // then the open tag - grouped into one undo step since these are conceptually one edit
            linkedInput.BeginComplexOperation();
            linkedInput.Select(0, selEnd, 0, selEnd + closeTag.Length);
            linkedInput.InsertTextAtCaret("");
            linkedInput.Select(0, selStart - openTag.Length, 0, selStart);
            linkedInput.InsertTextAtCaret("");
            linkedInput.EndComplexOperation();
            int newStart = selStart - openTag.Length;
            linkedInput.Select(0, newStart, 0, newStart + originalSelection.Length);
            return;
        }

        // Case: tag pair exists INSIDE the selection -> strip the inner pair, wrap the whole selection
        if (originalSelection.Contains(openTag) && originalSelection.Contains(closeTag))
        {
            string innerStripped = originalSelection.Replace(openTag, "").Replace(closeTag, "");
            string wrapped = EncaseWith(innerStripped, encase);
            linkedInput.InsertTextAtCaret(wrapped); // replaces the current selection
            int innerStart = selStart + openTag.Length;
            linkedInput.Select(0, innerStart, 0, innerStart + innerStripped.Length);
            return;
        }

        // Fallback: walk backward from selection start to see if we're inside an enclosing tag
        bool isInsideEnclosingTag = WithinTag(selStart, fullText, encase);
        string modifiedText = EncaseWith(originalSelection, encase, isInsideEnclosingTag);
        linkedInput.InsertTextAtCaret(modifiedText); // replaces the current selection
        string leadTag = isInsideEnclosingTag ? closeTag : openTag;
        int finalStart = selStart + leadTag.Length;
        linkedInput.Select(0, finalStart, 0, finalStart + originalSelection.Length);
    }

    void TransferText()
    {
        linkedOutput.Text = linkedInput.Text;
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