/// Camera permission authorization state.
enum AuthorizationState {
  undetermined(0),
  authorized(1),
  denied(2);

  const AuthorizationState(this.rawValue);

  factory AuthorizationState.fromRawValue(int value) {
    switch (value) {
      case 1:
        return AuthorizationState.authorized;
      case 2:
        return AuthorizationState.denied;
      default:
        return AuthorizationState.undetermined;
    }
  }

  final int rawValue;
}
