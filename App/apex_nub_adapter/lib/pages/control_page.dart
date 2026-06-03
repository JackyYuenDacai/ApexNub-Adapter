import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'mouse_control_tab.dart';
import 'keyboard_tab.dart';

class ControlPage extends StatefulWidget {
  final BleDevice device;

  const ControlPage({super.key, required this.device});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.mouse),
              text: 'Mouse',
            ),
            Tab(
              icon: Icon(Icons.keyboard),
              text: 'Keyboard',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          MouseControlTab(device: widget.device),
          KeyboardTab(device: widget.device),
        ],
      ),
    );
  }
}

