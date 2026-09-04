import 'active_status.dart';

/// Who a mutation-applied [ActiveStatus] lands on when [AbilityEngine]
/// resolves it. Most mutations (e.g. Combustão) debuff the opponent — the
/// default — but a defensive one (e.g. Guarda) needs to protect whoever's
/// using it instead.
enum StatusTarget { actor, opponent }

/// An [ActiveStatus] paired with who it targets — see
/// [AbilityEffect.statusesToApply].
class TargetedStatus {
  final ActiveStatus status;
  final StatusTarget target;

  const TargetedStatus({
    required this.status,
    this.target = StatusTarget.opponent,
  });
}
