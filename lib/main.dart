import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'main.g.dart'; // Run build_runner to generate adapter files

@HiveType(typeId: 0)
class Device extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  HiveList<Schedule>? schedules;

  Device({required this.name});
}

@HiveType(typeId: 1)
class Schedule extends HiveObject {
  @HiveField(0)
  String time;

  Schedule({required this.time});
}

// ------------------ MAIN APP ------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(DeviceAdapter());
  Hive.registerAdapter(ScheduleAdapter());

  // Open boxes
  await Hive.openBox<Device>('devices');
  await Hive.openBox<Schedule>('schedules');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Device Scheduler',
      home: DevicePage(),
    );
  }
}

// ------------------ DEVICE PAGE ------------------

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  _DevicePageState createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final deviceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final deviceBox = Hive.box<Device>('devices');

    return Scaffold(
      appBar: AppBar(title: Text("Devices & Schedules")),
      body: ValueListenableBuilder(
        valueListenable: deviceBox.listenable(),
        builder: (context, Box<Device> box, _) {
          if (box.values.isEmpty) {
            return Center(child: Text("No devices added"));
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final device = box.getAt(index);
              return Card(
                child: ListTile(
                  title: Text(device!.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (device.schedules != null &&
                          device.schedules!.isNotEmpty)
                        ...device.schedules!
                            .map((s) => Text("⏰ ${s.time}"))
                            .toList(),
                      if (device.schedules == null || device.schedules!.isEmpty)
                        Text("No schedules yet"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add_alarm),
                    onPressed: () async {
                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );

                      if (picked != null) {
                        final formatted = picked.format(
                          context,
                        ); // e.g. 09:00 AM
                        final schedule = Schedule(time: formatted);
                        Hive.box<Schedule>('schedules').add(schedule);

                        setState(() {
                          device.schedules ??= HiveList(
                            Hive.box<Schedule>('schedules'),
                          );
                          device.schedules!.add(schedule);
                          device.save();
                        });

                        printDevicesAndSchedules(); // Print in terminal
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddDeviceDialog(context);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddDeviceDialog(BuildContext context) {
    final deviceBox = Hive.box<Device>('devices');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Add Device"),
        content: TextField(
          controller: deviceController,
          decoration: InputDecoration(hintText: "Enter device name"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (deviceController.text.isNotEmpty) {
                final device = Device(name: deviceController.text);
                deviceBox.add(device);
                deviceController.clear();
                Navigator.pop(context);
                printDevicesAndSchedules(); // print in terminal
              }
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }
}

// ------------------ DEBUG PRINT ------------------

void printDevicesAndSchedules() {
  final deviceBox = Hive.box<Device>('devices');

  if (kDebugMode) {
    print("=== Hive Devices & Schedules ===");
  }
  for (var i = 0; i < deviceBox.length; i++) {
    final device = deviceBox.getAt(i);
    if (kDebugMode) {
      print("Device $i → ${device?.name}");
    }
    device?.schedules?.forEach((s) {
      if (kDebugMode) {
        print("   Schedule → ${s.time}");
      }
    });
  }
  if (kDebugMode) {
    print("================================");
  }
}
