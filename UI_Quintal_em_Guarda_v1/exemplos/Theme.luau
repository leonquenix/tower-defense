--!strict
return table.freeze({
 Colors = table.freeze({
  Ink = Color3.fromRGB(25,40,63), Cream = Color3.fromRGB(255,243,214),
  Paper = Color3.fromRGB(255,250,236), Teal = Color3.fromRGB(47,183,160),
  Gold = Color3.fromRGB(255,200,87), Coral = Color3.fromRGB(255,119,94),
  Enemy = Color3.fromRGB(125,99,184), Cyan = Color3.fromRGB(99,205,232),
  Danger = Color3.fromRGB(182,62,72), Muted = Color3.fromRGB(82,97,116),
 }),
 Radius = table.freeze({Panel = 20, Button = 12}),
 MinimumTouchSize = 44,
 PreferredTouchSize = 48,
 Font = Enum.Font.BuilderSans,
 BoldFont = Enum.Font.BuilderSansBold,
 DisplayOrder = table.freeze({World = 0, HUD = 10, Menu = 20, Modal = 30, Toast = 40}),
})
