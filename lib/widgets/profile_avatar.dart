import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class ProfileAvatar extends StatelessWidget {
  final double radius;
  final VoidCallback? onTap;
  final bool showEditButton;

  const ProfileAvatar({
    super.key,
    this.radius = 50,
    this.onTap,
    this.showEditButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) => GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            CircleAvatar(
              radius: radius.r,
              backgroundColor: Colors.grey[200],
              backgroundImage: userProvider.user?.photoURL != null
                  ? NetworkImage(userProvider.user!.photoURL!)
                  : null,
              child: userProvider.user?.photoURL == null
                  ? Icon(
                Icons.person,
                size: (radius).r,
                color: Colors.grey[400],
              )
                  : null,
            ),
            if (showEditButton)
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: (radius * 0.3).r,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Icon(
                    Icons.camera_alt,
                    size: (radius * 0.3).r,
                    color: Colors.white,
                  ),
                ),
              ),
            if (userProvider.isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: (radius * 0.4).r,
                      height: (radius * 0.4).r,
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}