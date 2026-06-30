using System;

/// <summary>
/// The result of toggling a tag on a piece of text: the new full text, and where
/// the selection should end up within it.
/// </summary>
public struct TagEditResult
{
    public string NewText;
    public int SelectionStart;
    public int SelectionEnd; // equal to SelectionStart when nothing should be selected (just a caret)
}

/// <summary>
/// Pure BBCode tag-toggling logic, with no dependency on Godot or any specific
/// text control. Given the current text and selection bounds, decides how a tag
/// should be applied or removed and returns the result as plain data, so the
/// caller (a Godot node, a unit test, anything) can apply it however it needs to.
/// </summary>
public class BBCodeTagEditor
{
    /// <summary>
    /// Toggles the given tag on the current selection.
    /// </summary>
    /// <param name="fullText">The complete current text.</param>
    /// <param name="hasSelection">Whether there is an active selection.</param>
    /// <param name="selStart">Start offset of the selection (or caret position if none).</param>
    /// <param name="selectedText">The currently selected text (ignored if hasSelection is false).</param>
    /// <param name="encase">The tag name to apply or remove, e.g. "b" or "i".</param>
    public TagEditResult ToggleTag(string fullText, bool hasSelection, int selStart, string selectedText, string encase)
    {
        string openTag = $"[{encase}]";
        string closeTag = $"[/{encase}]";

        if (!hasSelection)
        {
            return ToggleTagAtCaret(fullText, selStart, encase, openTag, closeTag);
        }

        int selEnd = selStart + selectedText.Length;

        // Case: selection itself starts and ends with the tag pair -> strip them
        if (selectedText.StartsWith(openTag) && selectedText.EndsWith(closeTag)
            && selectedText.Length >= openTag.Length + closeTag.Length)
        {
            return StripEdgeTags(fullText, selStart, selectedText, openTag, closeTag);
        }

        // Case: tags sit just outside the selection (adjacent, not selected) -> strip them
        bool hasOpenBefore = selStart >= openTag.Length
            && fullText.Substring(selStart - openTag.Length, openTag.Length) == openTag;
        bool hasCloseAfter = selEnd + closeTag.Length <= fullText.Length
            && fullText.Substring(selEnd, closeTag.Length) == closeTag;
        if (hasOpenBefore && hasCloseAfter)
        {
            return StripAdjacentTags(fullText, selStart, selEnd, selectedText, openTag, closeTag);
        }

        // Case: tag pair exists INSIDE the selection -> strip the inner pair, wrap the whole selection
        if (selectedText.Contains(openTag) && selectedText.Contains(closeTag))
        {
            return StripInnerAndWrap(fullText, selStart, selectedText, encase, openTag, closeTag);
        }

        // Case: selection has no tag markers touching it at all, but sits somewhere inside
        // an already-tagged region -> close the existing tag before the selection and reopen it after
        return CloseAndReopenAround(fullText, selStart, selectedText, encase, openTag, closeTag);
    }

    TagEditResult ToggleTagAtCaret(string fullText, int caretPos, string encase, string openTag, string closeTag)
    {
        bool withinTag = WithinTag(caretPos, fullText, encase);
        string insertText = withinTag ? $"{closeTag}{openTag}" : $"{openTag}{closeTag}";
        string newText = fullText.Insert(caretPos, insertText);
        string firstTag = withinTag ? closeTag : openTag;
        int caret = caretPos + firstTag.Length;
        return new TagEditResult { NewText = newText, SelectionStart = caret, SelectionEnd = caret };
    }

    TagEditResult StripEdgeTags(string fullText, int selStart, string selectedText, string openTag, string closeTag)
    {
        string stripped = selectedText.Substring(
            openTag.Length,
            selectedText.Length - openTag.Length - closeTag.Length);
        string newText = fullText.Remove(selStart, selectedText.Length).Insert(selStart, stripped);
        return new TagEditResult
        {
            NewText = newText,
            SelectionStart = selStart,
            SelectionEnd = selStart + stripped.Length
        };
    }

    TagEditResult StripAdjacentTags(string fullText, int selStart, int selEnd, string selectedText, string openTag, string closeTag)
    {
        // remove the close tag first (it's after the selection, doesn't shift earlier offsets), then the open tag
        string newText = fullText.Remove(selEnd, closeTag.Length)
                                  .Remove(selStart - openTag.Length, openTag.Length);
        int newStart = selStart - openTag.Length;
        return new TagEditResult
        {
            NewText = newText,
            SelectionStart = newStart,
            SelectionEnd = newStart + selectedText.Length
        };
    }

    TagEditResult StripInnerAndWrap(string fullText, int selStart, string selectedText, string encase, string openTag, string closeTag)
    {
        string innerStripped = selectedText.Replace(openTag, "").Replace(closeTag, "");
        string wrapped = $"{openTag}{innerStripped}{closeTag}";
        string newText = fullText.Remove(selStart, selectedText.Length).Insert(selStart, wrapped);
        int innerStart = selStart + openTag.Length;
        return new TagEditResult
        {
            NewText = newText,
            SelectionStart = innerStart,
            SelectionEnd = innerStart + innerStripped.Length
        };
    }

    TagEditResult CloseAndReopenAround(string fullText, int selStart, string selectedText, string encase, string openTag, string closeTag)
    {
        bool isInsideEnclosingTag = WithinTag(selStart, fullText, encase);
        string modifiedText = isInsideEnclosingTag
            ? $"{closeTag}{selectedText}{openTag}"
            : $"{openTag}{selectedText}{closeTag}";
        string newText = fullText.Remove(selStart, selectedText.Length).Insert(selStart, modifiedText);
        string leadTag = isInsideEnclosingTag ? closeTag : openTag;
        int finalStart = selStart + leadTag.Length;
        return new TagEditResult
        {
            NewText = newText,
            SelectionStart = finalStart,
            SelectionEnd = finalStart + selectedText.Length
        };
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
}