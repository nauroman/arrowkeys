// Installer anchors this transparent canvas to the lower left of its window.
// The text pane starts 182 pt from the left. Its lower border is 49–51 pt
// above the bottom on macOS 15 and 26.
const sidebarWidth = 182;
const textPaneBottom = 50;
const iconSize = 128;
const iconBottomPadding = 23; // Transparent margin in the scaled ArrowKeys icon.
const canvas = new Canvas(sidebarWidth, iconSize + textPaneBottom - iconBottomPadding);
canvas.drawImage(sips.images[0], (sidebarWidth - iconSize) / 2, 0, iconSize, iconSize);
new Output(canvas, sips.outputPath, "png").addToQueue();
