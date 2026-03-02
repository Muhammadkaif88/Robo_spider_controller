import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const SpiderApp());
}

class SpiderApp extends StatelessWidget {
  const SpiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spider Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.tealAccent,
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.pinkAccent,
        ),
      ),
      home: const DeviceListScreen(),
    );
  }
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  List<BluetoothDevice> _devices = [];
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() => _bluetoothState = state);
    });

    FlutterBluetoothSerial.instance.onStateChanged().listen((
      BluetoothState state,
    ) {
      setState(() => _bluetoothState = state);
      if (state == BluetoothState.STATE_ON) {
        _getPairedDevices();
      }
    });

    if (await FlutterBluetoothSerial.instance.isEnabled == true) {
      _getPairedDevices();
    }
  }

  Future<void> _getPairedDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance
          .getBondedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      debugPrint("Error getting devices: $e");
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() => _isConnecting = true);
    try {
      BluetoothConnection connection = await BluetoothConnection.toAddress(
        device.address,
      );
      setState(() => _isConnecting = false);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ControllerScreen(device: device, connection: connection),
          ),
        ).then((_) {
          // Re-fetch connection status on return
          setState(() {});
        });
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot connect to ${device.name}, error: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Spider Robot'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getPairedDevices,
          ),
        ],
      ),
      body: _bluetoothState != BluetoothState.STATE_ON
          ? const Center(child: Text("Please turn on Bluetooth"))
          : _isConnecting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.tealAccent),
                  SizedBox(height: 20),
                  Text("Connecting..."),
                ],
              ),
            )
          : _devices.isEmpty
          ? const Center(child: Text('No paired devices found'))
          : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFF2A2A3C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.bluetooth,
                      color: Colors.tealAccent,
                    ),
                    title: Text(device.name ?? "Unknown Device"),
                    subtitle: Text(device.address),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _connectToDevice(device),
                      child: const Text('Connect'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ControllerScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothConnection connection;

  const ControllerScreen({
    super.key,
    required this.device,
    required this.connection,
  });

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  bool motor1State = false;
  bool motor2State = false;
  bool motor3State = false;

  void _sendCommand(String command) {
    if (widget.connection.isConnected) {
      widget.connection.output.add(ascii.encode(command));
    }
  }

  @override
  void dispose() {
    widget.connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name ?? "Spider Controller"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Directional Pad
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3C),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(76),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildNavButton(
                      Icons.keyboard_arrow_up,
                      'F',
                      Colors.tealAccent,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildNavButton(
                          Icons.keyboard_arrow_left,
                          'L',
                          Colors.pinkAccent,
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.adb, size: 40, color: Colors.white54),
                        const SizedBox(width: 20),
                        _buildNavButton(
                          Icons.keyboard_arrow_right,
                          'R',
                          Colors.pinkAccent,
                        ),
                      ],
                    ),
                    _buildNavButton(
                      Icons.keyboard_arrow_down,
                      'B',
                      Colors.tealAccent,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Actions Row
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 15,
                runSpacing: 15,
                children: [
                  _buildActionButton('Stand', 'X', Icons.arrow_upward),
                  _buildActionButton('Sit', 'x', Icons.arrow_downward),
                  _buildActionButton('Wave', 'W', Icons.waving_hand),
                  _buildActionButton('Dance', 'U', Icons.music_note),
                  _buildActionButton('Calibrate', 'C', Icons.build),
                ],
              ),

              const SizedBox(height: 40),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),

              // Motors Section
              const Text(
                'External Motors',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              _buildMotorSwitch(
                label: 'Motor A1',
                value: motor1State,
                onChanged: (val) {
                  setState(() => motor1State = val);
                  _sendCommand(val ? '1' : '2');
                },
              ),
              const SizedBox(height: 10),
              _buildMotorSwitch(
                label: 'Motor A2',
                value: motor2State,
                onChanged: (val) {
                  setState(() => motor2State = val);
                  _sendCommand(val ? '3' : '4');
                },
              ),
              const SizedBox(height: 10),
              _buildMotorSwitch(
                label: 'Motor A3',
                value: motor3State,
                onChanged: (val) {
                  setState(() => motor3State = val);
                  _sendCommand(val ? '5' : '6');
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String command, Color color) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTapDown: (_) =>
            _sendCommand(command), // Can send continuous if configured
        onTapUp: (_) => _sendCommand('S'), // Stop command if handled
        onTapCancel: () => _sendCommand('S'),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(51),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, size: 40, color: color),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, String command, IconData icon) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _sendCommand(command),
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: const Color(0xFF3B3B54),
            foregroundColor: Colors.white,
          ),
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildMotorSwitch({
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3C),
        borderRadius: BorderRadius.circular(15),
      ),
      child: SwitchListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.tealAccent,
        activeTrackColor: Colors.tealAccent.withAlpha(76),
        inactiveThumbColor: Colors.white54,
        inactiveTrackColor: Colors.white10,
        secondary: Icon(
          Icons.settings_input_component,
          color: value ? Colors.tealAccent : Colors.white54,
        ),
      ),
    );
  }
}
