import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();
  @override
  List<Object?> get props => [];
}

class AnalyticsLoaded extends AnalyticsEvent {}

class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.duration = Duration.zero,
    this.peakViewers = 0,
    this.rtmpSuccessRate = 0,
  });
  final Duration duration;
  final int peakViewers;
  final double rtmpSuccessRate;
  @override
  List<Object?> get props => [duration, peakViewers, rtmpSuccessRate];
}

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc() : super(const AnalyticsState()) {
    on<AnalyticsLoaded>((event, emit) => emit(state));
  }
}
