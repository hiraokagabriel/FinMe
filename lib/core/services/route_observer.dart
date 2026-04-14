import 'package:flutter/material.dart';

/// RouteObserver global. Registrado no MaterialApp e consumido por
/// qualquer página que precise reagir a didPopNext (ex: CardsPage).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
