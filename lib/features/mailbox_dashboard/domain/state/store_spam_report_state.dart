import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';

class StoreSpamReportStateLoading extends UIState {}

class StoreSpamReportStateSuccess extends UIState {}

class StoreSpamReportStateFailure extends FeatureFailure {

  StoreSpamReportStateFailure(dynamic exception) : super(exception: exception);
}