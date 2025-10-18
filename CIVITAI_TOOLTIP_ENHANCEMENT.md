# CivitAI Browser Enhancement: Model Type Tooltips

## Enhancement Overview
Added mouseover tooltips that display the model type (Checkpoint, LoRA, TextualInversion, etc.) when hovering over CivitAI model cards.

## Files Modified

### 1. `/extensions/sd-civitai-browser-plus/scripts/civitai_api.py`
- **Line ~272**: Modified figcaption title to include model type in format: `"ModelName (Type: ModelType)"`
- **Line ~261**: Added `model-type` data attribute to figure elements for JavaScript access
- **Changes**: 
  - Enhanced tooltip text in figcaption title attribute
  - Added model type as HTML data attribute for programmatic access

### 2. `/extensions/sd-civitai-browser-plus/javascript/civitai-html.js`
- **Added Functions**:
  - `createModelTypeTooltips()`: Creates floating tooltips on model cards
  - `updateModelTypeTooltips()`: Refreshes tooltips when content changes
  - `setupModelListObserver()`: Monitors DOM changes to maintain tooltips
- **Integration**: Added calls in `onPageLoad()` function to initialize tooltip system
- **Features**:
  - Dynamic tooltip creation for all model cards
  - Automatic tooltip updates when new cards are loaded
  - Smooth fade-in/fade-out animations
  - Positioned at top-left of each card for visibility

### 3. `/extensions/sd-civitai-browser-plus/style.css`
- **Added**: `.civitai-model-tooltip` styling with enhanced visual effects
- **Features**:
  - Modern gradient background with backdrop blur
  - Smooth transition animations
  - High z-index for proper layering
  - Enhanced shadow and border effects
  - Responsive hover states

## How It Works

1. **Python Backend**: Model type information from CivitAI API is now included in both:
   - HTML title attribute for native browser tooltips
   - HTML data attribute for JavaScript access

2. **JavaScript Frontend**: 
   - Automatically creates custom floating tooltips for all model cards
   - Monitors for new content and maintains tooltips as user browses
   - Provides smooth hover animations and positioning

3. **CSS Styling**: 
   - Modern, visually appealing tooltip design
   - Ensures tooltips are visible above all other content
   - Smooth animations for professional feel

## User Experience

- **Hover over any model image**: See "Type: [ModelType]" tooltip appear
- **Native tooltip**: Figcaption still shows full model name and type
- **Dynamic updates**: Tooltips automatically appear on newly loaded content
- **No performance impact**: Lightweight implementation with efficient DOM monitoring

## Model Types Supported
All CivitAI model types including:
- Checkpoint
- LoRA  
- TextualInversion
- Hypernetwork
- VAE
- ControlNet
- Upscaler
- And more...

## Installation
Changes are automatically active after:
1. Restarting Stable Diffusion WebUI
2. Or refreshing the CivitAI Browser tab

No additional configuration required - works immediately upon restart.