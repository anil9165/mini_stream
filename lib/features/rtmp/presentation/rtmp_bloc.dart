import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/rtmp_destination.dart';
import '../domain/rtmp_repository.dart';

sealed class RtmpEvent extends Equatable {
  const RtmpEvent();
  @override
  List<Object?> get props => [];
}

class WatchRtmpDestinations extends RtmpEvent {}

class SaveRtmpDestination extends RtmpEvent {
  const SaveRtmpDestination(this.destination);
  final RtmpDestination destination;
  @override
  List<Object?> get props => [destination];
}

class _RtmpUpdated extends RtmpEvent {
  const _RtmpUpdated(this.destinations);
  final List<RtmpDestination> destinations;
  @override
  List<Object?> get props => [destinations];
}

class _RtmpWatchFailed extends RtmpEvent {
  const _RtmpWatchFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

sealed class RtmpState extends Equatable {
  const RtmpState();
  @override
  List<Object?> get props => [];
}

class RtmpInitial extends RtmpState {}

class RtmpLoading extends RtmpState {}

class RtmpLoaded extends RtmpState {
  const RtmpLoaded(this.destinations);
  final List<RtmpDestination> destinations;
  @override
  List<Object?> get props => [destinations];
}

class RtmpSaved extends RtmpState {}

class RtmpError extends RtmpState {
  const RtmpError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class RtmpBloc extends Bloc<RtmpEvent, RtmpState> {
  RtmpBloc(this._repository) : super(RtmpInitial()) {
    on<WatchRtmpDestinations>(_watch);
    on<_RtmpUpdated>((event, emit) => emit(RtmpLoaded(event.destinations)));
    on<_RtmpWatchFailed>((event, emit) => emit(RtmpError(event.message)));
    on<SaveRtmpDestination>(_save);
  }

  final IRtmpRepository _repository;
  StreamSubscription<List<RtmpDestination>>? _subscription;

  Future<void> _watch(
    WatchRtmpDestinations event,
    Emitter<RtmpState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = _repository.watchDestinations().listen(
      (items) => add(_RtmpUpdated(items)),
      onError: (Object error) => add(_RtmpWatchFailed(error.toString())),
    );
  }

  Future<void> _save(SaveRtmpDestination event, Emitter<RtmpState> emit) async {
    final validation = _repository.validate(event.destination);
    if (validation.isNotEmpty) {
      emit(RtmpError(validation));
      return;
    }
    try {
      await _repository.saveDestination(event.destination);
      emit(RtmpSaved());
    } catch (error) {
      emit(RtmpError(error.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
