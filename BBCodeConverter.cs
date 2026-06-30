using Godot;
using System;
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
    public void MakeBold()
    {
        EncaseSelectedWith("b");
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
        RunEncaseLogicOnSelection(encase);
        TransferText();
    }

    /// <summary>
    /// Applies or removes the given BBCode tag from the current selection, whether the
    /// tag is already part of the selection, just outside it, nested inside it, or
    /// enclosing it elsewhere in the text - so that formatting toggles intuitively
    /// regardless of how the existing tags relate to what's selected.
    /// </summary>
    /// <param name="encase">The tag name to apply or remove, e.g. "b" or "i".</param>
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

        // Case: selection has no tag markers touching it at all, but sits somewhere inside
        // an already-tagged region (e.g. selecting a word in the middle of bold text) ->
        // close the existing tag before the selection and reopen it after
        bool isInsideEnclosingTag = WithinTag(selStart, fullText, encase);
        string modifiedText = EncaseWith(originalSelection, encase, isInsideEnclosingTag);
        linkedInput.InsertTextAtCaret(modifiedText); // replaces the current selection
        string leadTag = isInsideEnclosingTag ? closeTag : openTag;
        int finalStart = selStart + leadTag.Length;
        linkedInput.Select(0, finalStart, 0, finalStart + originalSelection.Length);
    }

    /// <summary>
    /// Produces the BBCode-wrapped form of a piece of text.
    /// </summary>
    /// <param name="text">The text to wrap.</param>
    /// <param name="encase">The tag name, e.g. "b" or "i".</param>
    /// <param name="inverse">
    /// True if an enclosing tag is being closed and reopened around the text,
    /// rather than the text being newly wrapped.
    /// </param>
    string EncaseWith(string text, string encase, bool inverse = false)
    {
        if (inverse)
        {
            return $"[/{encase}]{text}[{encase}]";
        }
        return $"[{encase}]{text}[/{encase}]";
    }

    /// <summary>
    /// Determines whether a position in the text already falls inside an existing
    /// tag of the given type, so formatting can be toggled rather than blindly applied.
    /// </summary>
    /// <param name="index">The offset to check.</param>
    /// <param name="text">The full text to check against.</param>
    /// <param name="element">The tag name to look for, e.g. "b" or "i".</param>
    bool WithinTag(int index, string text, string element)
    {
        string openTag = $"[{element}]";
        string closeTag = $"[/{element}]";
        for (int i = index - 1; i >= 0; i--)
        {
            if (text[i] != ']')
            {
                continue;
            }
            int closeStart = i - closeTag.Length + 1;
            if (closeStart >= 0 && text.Substring(closeStart, closeTag.Length) == closeTag)
            {
                return false;
            }
            int openStart = i - openTag.Length + 1;
            if (openStart >= 0 && text.Substring(openStart, openTag.Length) == openTag)
            {
                return true;
            }
        }
        return false;
    }

    /// <summary>
    /// Keeps the rendered preview in sync with the raw BBCode input.
    /// </summary>
    void TransferText()
    {
        linkedOutput.Text = linkedInput.Text;
    }
}