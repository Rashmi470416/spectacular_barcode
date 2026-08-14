/// Camera facing direction.
enum CameraFacing {
  front(0),
  back(1),
  external(2),
  unknown(-1);

  const CameraFacing(this.rawValue);

  factory CameraFacing.fromRawValue(int? value) {
    switch (value) {
      case 0:
        return CameraFacing.front;
      case 1:
        return CameraFacing.back;
      case 2:
        return CameraFacing.external;
      default:
        return CameraFacing.unknown;
    }
  }

  final int rawValue;
}
