// lib/core/providers/model_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cw/Models/user_model.dart';
import 'package:cw/Models/household_model.dart';
final userModelProvider = StateProvider<UserModel?>((ref) => null);
final householdModelProvider = StateProvider<Household?>((ref) => null);