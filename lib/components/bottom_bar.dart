import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responder/pages/chatPages/chat_list.dart';

import '../pages/announcement_page.dart';
import '../pages/home_page.dart';
import '../pages/map_page.dart';
import '../services/database.dart';
import 'setting.dart';


class BottomNavBar extends StatefulWidget {
  final String currentPage;

  const BottomNavBar({Key? key, required this.currentPage}) : super(key: key);

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  final DatabaseService _dbService = DatabaseService();

  void _onItemTapped(String page) {
    if (page == widget.currentPage) return;

    switch (page) {
      case 'home':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const HomePage(currentPage: 'home')),
        );
        break;
      case 'chats':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatListPage(currentPage: 'chats')),
        );
        break;
      case 'settings':
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SettingsWidget(),
            );
          },
        );
        break;
      case 'report':
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //       builder: (context) =>
        //           ReportsSummaryPage(currentPage: 'SummaryReport')),
        // );
        break;
      case 'announcement':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  AnnouncementsPage(currentPage: 'announcement')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _getSelectedIndex(widget.currentPage),
      onTap: (index) {
        String page = _getPageFromIndex(index);
        _onItemTapped(page);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.report),
          label: 'Log Book',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Updates',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Setting',
        ),
      ],
    );
  }

  int _getSelectedIndex(String page) {
    switch (page) {
      case 'home':
        return 0;
      case 'SummaryReport':
        return 1;
      case 'announcement':
        return 2;
      case 'chats':
        return 3;
      case 'settings':
        return 4;

      default:
        return 0;
    }
  }

  String _getPageFromIndex(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'report';
      case 2:
        return 'announcement';
      case 3:
        return 'chats';
      case 4:
        return 'settings';

      default:
        return 'home';
    }
  }
}
