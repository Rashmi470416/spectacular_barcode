/// Flashlight / torch state.
enum TorchState {
  unavailable(-1),
  off(0),
  on(1);

  const TorchState(this.rawValue);

  factory TorchState.fromRawValue(int value) {
    switch (value) {
      case -1:
        return TorchState.unavailable;
      case 0:
        return TorchState.off;
      case 1:
        return TorchState.on;
      default:
        return TorchState.unavailable;
    }
  }

  final int rawValue;
}
