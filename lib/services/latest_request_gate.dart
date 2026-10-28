class LatestRequestGate {
  int _generation = 0;

  int begin() => ++_generation;

  void invalidate() => _generation++;

  bool isLatest(int generation) => generation == _generation;
}
