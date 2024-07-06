import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorage.webStorageDirectory
        : await getTemporaryDirectory(),
  );
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BrightnessCubit(),
      child: const AppView(),
    );
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BrightnessCubit, Brightness>(
      builder: (context, brightness) {
        return MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const CounterPage(),
        );
      },
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollectionCubit>(
      create: (_) => CollectionCubit(),
      child: const CounterView(),
    );
  }
}

class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: BlocBuilder<CollectionCubit, List<CounterBloc>>(
          builder: (context, state) {
            return ListView.builder(
              // Let the ListView know how many items it needs to build.
              itemCount: state.length,
              // Provide a builder function. This is where the magic happens.
              // Convert each item into a widget based on the type of item it is.
              itemBuilder: (context, index) {
                final item = state[index];
                return BlocProvider(
                  create: (context) => item,
                  child: createListTile(context),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            child: const Icon(Icons.brightness_6),
            onPressed: () => context.read<BrightnessCubit>().toggleBrightness(),
          ),
          const SizedBox(height: 4),
          FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () {
              context.read<CollectionCubit>().addCounter();
            },
          ),
          const SizedBox(height: 4),
          FloatingActionButton(
            child: const Icon(Icons.delete_forever),
            onPressed: () => HydratedBloc.storage.clear(),
          ),
        ],
      ),
    );
  }

  Widget createListTile(BuildContext context) {
    return BlocBuilder<CounterBloc, CounterState>(
      builder: (context, state) {
        return ListTile(
          title: Center(child: Text("${state.value}")),
          subtitle: Column(
            children: <Widget>[
              Text(state.uuid),
              ButtonBar(children: [
                TextButton(
                    child: const Text('+'),
                    onPressed: () {
                      context
                          .read<CounterBloc>()
                          .add(CounterIncrementPressed());
                    }),
                TextButton(
                    child: const Text('-'),
                    onPressed: () {
                      context
                          .read<CounterBloc>()
                          .add(CounterDecrementPressed());
                    }),
              ])
            ],
          ),
        );
      },
    );
  }
}

sealed class CounterEvent {}

final class CounterIncrementPressed extends CounterEvent {}

final class CounterDecrementPressed extends CounterEvent {}

class CounterState {
  final int value;
  final String uuid;

  CounterState({required this.value, required this.uuid});

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'uuid': uuid,
    };
  }

  static CounterState fromJson(Map<String, dynamic> json) {
    return CounterState(
      value: json['value'],
      uuid: json["uuid"],
    );
  }
}

class CounterBloc extends HydratedBloc<CounterEvent, CounterState> {
  CounterBloc(super.initialState) {
    on<CounterIncrementPressed>((event, emit) =>
        emit(CounterState(value: state.value + 1, uuid: state.uuid)));
    on<CounterDecrementPressed>((event, emit) =>
        emit(CounterState(value: state.value - 1, uuid: state.uuid)));
  }

  @override
  String get id => state.uuid;

  @override
  CounterState fromJson(Map<String, dynamic> json) =>
      CounterState.fromJson(json);

  @override
  Map<String, dynamic> toJson(CounterState state) => state.toJson();
}

class CollectionCubit extends HydratedCubit<List<CounterBloc>> {
  CollectionCubit() : super([]);

  void addCounter() {
    final newCounter =
        CounterBloc(CounterState(uuid: const Uuid().v4(), value: 0));
    final updatedList = List<CounterBloc>.from(state)..add(newCounter);
    emit(updatedList);
  }

  @override
  List<CounterBloc> fromJson(Map<String, dynamic> json) {
    final counters = json['counters'] as List;
    return counters
        .map((counter) => CounterBloc(CounterState.fromJson(counter)))
        .toList();
  }

  @override
  Map<String, dynamic> toJson(List<CounterBloc> state) {
    return {
      'counters': state.map((bloc) => bloc.state.toJson()).toList(),
    };
  }
}

class BrightnessCubit extends HydratedCubit<Brightness> {
  BrightnessCubit() : super(Brightness.light);

  void toggleBrightness() {
    emit(state == Brightness.light ? Brightness.dark : Brightness.light);
  }

  @override
  Brightness fromJson(Map<String, dynamic> json) {
    return Brightness.values[json['brightness'] as int];
  }

  @override
  Map<String, dynamic> toJson(Brightness state) {
    return <String, int>{'brightness': state.index};
  }
}
