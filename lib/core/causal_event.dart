import 'package:uuid/uuid.dart';

/// Every event in the trinity system is one of these types.
/// Each sub-system produces specific types:
/// - recoverable_app → [crashEvent]
/// - ui_explainer → [layoutDecision]
/// - causality_flutter → [userAction], [stateChange], [networkEvent], [uiRebuild]
enum CausalEventType {
  /// User-initiated action (tap, swipe, form submit).
  userAction,

  /// State management mutation (Provider notify, Bloc transition, Riverpod update).
  stateChange,

  /// Network request or response (Dio, http, WebSocket).
  networkEvent,

  /// Widget rebuild triggered by a state change.
  uiRebuild,

  /// Crash or unhandled exception intercepted by [ErrorInterceptor].
  crashEvent,

  /// Layout decision recorded by [ExplainableRenderBox].
  layoutDecision,

  /// Custom event emitted by user code via [InstrumentedNotifier.emitCause].
  custom,
}

/// A single node in the [CausalGraph].
///
/// Every event has a unique [id] and an optional [parentId] linking it to
/// the event that caused it. Together these form a directed acyclic graph (DAG)
/// where edges represent causal relationships.
///
/// The [parentId] is automatically set from [CausalityZone.currentContext()]
/// at emit time — developers rarely need to set it manually.
class CausalEvent {
  /// Unique identifier (UUID v4). Auto-generated if not provided.
  final String id;

  /// The ID of the event that caused this one. Null for root events (e.g. user taps).
  final String? parentId;

  /// What kind of event this is. Determines color coding in DevTools.
  final CausalEventType type;

  /// Human-readable description: "user_tapped_login", "POST /api/cart", etc.
  final String description;

  /// When this event occurred.
  final DateTime timestamp;

  /// Arbitrary key-value metadata (error_type, http_status, widget_type, etc.).
  final Map<String, dynamic> metadata;

  /// For async spans (e.g. network requests), the wall-clock duration.
  final Duration? duration;

  CausalEvent({
    String? id,
    this.parentId,
    required this.type,
    required this.description,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    this.duration,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? const {};

  /// Serializes to JSON for DevTools transport, bug reports, and snapshot storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'type': type.name,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
        'duration_ms': duration?.inMilliseconds,
      };

  /// Deserializes from JSON. Throws [ArgumentError] if [type] field has an
  /// invalid enum name.
  factory CausalEvent.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String;
    final CausalEventType eventType;
    try {
      eventType = CausalEventType.values.byName(typeName);
    } catch (_) {
      throw ArgumentError('Invalid CausalEventType: "$typeName"');
    }

    return CausalEvent(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      type: eventType,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      duration: json['duration_ms'] != null
          ? Duration(milliseconds: json['duration_ms'] as int)
          : null,
    );
  }

  @override
  String toString() =>
      'CausalEvent(${type.name}: "$description" id=$id parent=$parentId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CausalEvent && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
