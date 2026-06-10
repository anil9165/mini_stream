import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class AdminEvent extends Equatable {
  const AdminEvent();
  @override
  List<Object?> get props => [];
}

class AdminBootstrapped extends AdminEvent {}

class AdminState extends Equatable {
  const AdminState({this.isReady = true});
  final bool isReady;
  @override
  List<Object?> get props => [isReady];
}

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc() : super(const AdminState()) {
    on<AdminBootstrapped>((event, emit) => emit(const AdminState()));
  }
}
