import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
part 'main.g.dart';

@HiveType(typeId: 0)
class Schedule extends HiveObject {
  @HiveField(0)
  String time;

  Schedule({required this.time});
}

// TypeAdapter for Schedule
class ScheduleAdapter extends TypeAdapter<Schedule> {
  @override
  final int typeId = 0;

  @override
  Schedule read(BinaryReader reader) {
    return Schedule(time: reader.readString());
  }

  @override
  void write(BinaryWriter writer, Schedule obj) {
    writer.writeString(obj.time);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ScheduleAdapter());
  await Hive.openBox<Schedule>('schedules');

  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Home',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      home: const SmartHomeTabs(),
    );
  }
}

class SmartHomeTabs extends StatefulWidget {
  const SmartHomeTabs({super.key});

  @override
  SmartHomeTabsState createState() => SmartHomeTabsState();
}

class SmartHomeTabsState extends State<SmartHomeTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Device> devices = [
    Device(name: "Living Room Light", type: "Light", isOn: false),
    Device(name: "Bedroom Fan", type: "Fan", isOn: true),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleBox = Hive.box<Schedule>('schedules');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Home"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.greenAccent,
          tabs: const [
            Tab(text: "Devices", icon: Icon(Icons.list)),
            Tab(text: "Control", icon: Icon(Icons.power_settings_new)),
            Tab(text: "Schedule", icon: Icon(Icons.schedule)),
            Tab(text: "Manage", icon: Icon(Icons.settings)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Device List
          ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              return Card(
                color: Colors.grey[900],
                child: ListTile(
                  leading: const Icon(Icons.devices, color: Colors.greenAccent),
                  title: Text(
                    devices[index].name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    devices[index].type,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: Icon(
                    devices[index].isOn ? Icons.toggle_on : Icons.toggle_off,
                    color: devices[index].isOn
                        ? Colors.greenAccent
                        : Colors.grey,
                    size: 40,
                  ),
                ),
              );
            },
          ),

          // Tab 2: Control (On/Off)
          ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              return SwitchListTile(
                title: Text(
                  devices[index].name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  "Tap to control",
                  style: TextStyle(color: Colors.grey),
                ),
                value: devices[index].isOn,
                onChanged: (value) {
                  setState(() {
                    devices[index].isOn = value;
                  });
                },
                activeColor: Colors.greenAccent,
              );
            },
          ),

          // Tab 3: Schedule (Hive integrated)
          Column(
            children: [
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: scheduleBox.listenable(),
                  builder: (context, Box<Schedule> box, _) {
                    if (box.values.isEmpty) {
                      return const Center(
                        child: Text(
                          "No schedules set",
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: box.values.length,
                      itemBuilder: (context, index) {
                        final schedule = box.getAt(index);
                        return Card(
                          color: Colors.grey[900],
                          child: ListTile(
                            title: Text(
                              "Scheduled at ${schedule?.time}",
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                box.deleteAt(index);
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.greenAccent,
                              onPrimary: Colors.black,
                              surface: Colors.black,
                              onSurface: Colors.white,
                            ),
                            dialogTheme: const DialogThemeData(
                              backgroundColor: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (!mounted || pickedTime == null) return;

                    final formatted = pickedTime.format(context);

                    scheduleBox.add(Schedule(time: formatted));

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Scheduled at $formatted"),
                        backgroundColor: Colors.grey[800],
                      ),
                    );
                  },
                  child: const Text("Set Schedule"),
                ),
              ),
            ],
          ),

          // Tab 4: Add/Delete Device
          ManageDevicesTab(
            devices: devices,
            onUpdate: (updatedList) {
              setState(() {
                devices = updatedList;
              });
            },
          ),
        ],
      ),
    );
  }
}

class Device {
  String name;
  String type;
  bool isOn;

  Device({required this.name, required this.type, this.isOn = false});
}

class ManageDevicesTab extends StatefulWidget {
  final List<Device> devices;
  final Function(List<Device>) onUpdate;

  const ManageDevicesTab({
    super.key,
    required this.devices,
    required this.onUpdate,
  });

  @override
  ManageDevicesTabState createState() => ManageDevicesTabState();
}

class ManageDevicesTabState extends State<ManageDevicesTab> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController typeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.devices.length,
            itemBuilder: (context, index) {
              return Card(
                color: Colors.grey[900],
                child: ListTile(
                  title: Text(
                    widget.devices[index].name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    widget.devices[index].type,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        widget.devices.removeAt(index);
                        widget.onUpdate(List.from(widget.devices));
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Device Name",
                  labelStyle: const TextStyle(color: Colors.greenAccent),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: typeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Device Type",
                  labelStyle: const TextStyle(color: Colors.greenAccent),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      typeController.text.isNotEmpty) {
                    setState(() {
                      widget.devices.add(
                        Device(
                          name: nameController.text,
                          type: typeController.text,
                        ),
                      );
                      widget.onUpdate(List.from(widget.devices));
                      nameController.clear();
                      typeController.clear();
                    });
                  }
                },
                child: const Text("Add Device"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
