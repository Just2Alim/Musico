int responsiveGridColumns(double width) {
  if (width >= 1000) return 4;
  if (width >= 600) return 3;
  return 2;
}
