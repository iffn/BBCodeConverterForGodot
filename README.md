# BBCodeConverterForGodot
A custom WYSIWYG (What You See Is What You Get) rich-text editor for Godot, enabling direct visual formatting and precise mouse selection without exposing underlying markup to the user.

This is done by using SubViewports with special versions of the text with for character identification through color and highlight/caret positioning.

This was created with `Godot_v4.7`

## How to use:
- Add the folder to you Godot resource folder.
- Open and run `BBCodeConverter.tscn`

## Architecture Diagram

```mermaid
flowchart LR
	%% Inputs and Controller
	User -->|Keystrokes & Clicks| RTE[RichTextEditor]
	
	%% Model
	RTE -->|Edits Text| TB[TextBuffer & ColorIDMapper]
	
	%% Views & Viewports Pipeline
	TB -->|Raw BBCode| VLabel[VisibleText Label]
	
	subgraph Viewports [The Dual Sub-Viewport Engine]
		HTV[HitTest Viewport<br><i>Decodes mouse clicks via RGB Color IDs</i>] 
		CSO[Selection Overlay<br><i>Draws cursors & highlights via shader</i>]
		
		HTV -->|Character Index| CSO
	end

	RTE -->|Coordinates| Viewports
	CSO -->|Shader Mask Texture| VLabel
