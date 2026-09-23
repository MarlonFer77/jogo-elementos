import 'package:battle_engine/battle_engine.dart';

String statusName(String id) =>
    StatusEffects.all.where((s) => s.id == id).firstOrNull?.name ?? id;
String statusDescription(String id) =>
    StatusEffects.all.where((s) => s.id == id).firstOrNull?.description ?? id;
