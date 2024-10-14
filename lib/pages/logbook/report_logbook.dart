import 'package:flutter/material.dart';

import '../../components/bottom_bar.dart';
import '../../services/database.dart';
import 'logBook_list.dart';
import 'report_list.dart';
import 'unsaved_logbook_.dart';

class ReportsLogBookPage extends StatefulWidget {
  final String currentPage;

  const ReportsLogBookPage({super.key, this.currentPage = 'logbook'});
  @override
  State<ReportsLogBookPage> createState() => _ReportsLogBookPageState();
}

class _ReportsLogBookPageState extends State<ReportsLogBookPage> {


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Now we have three tabs
      child: Scaffold(
        appBar: AppBar(
          title: Text('Reports & LogBook'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Reports'), // First tab
              Tab(text: 'LogBook'), // Second tab
              Tab(text: 'Unsaved Logs') // Third tab for Unsaved LogBooks
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ReportsListPage(), // Reports page
            LogBookListPage(), // LogBook page
            UnsavedLogBookListPage(), // Unsaved LogBook page
          ],
        ),

        bottomNavigationBar: BottomNavBar(currentPage: widget.currentPage),
      ),
      
    );
  }
}
