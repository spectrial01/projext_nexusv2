// widgets/metric_card.dart
import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class MetricCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String subtitle;
  final bool isRealTime;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.subtitle,
    this.isRealTime = false,
    this.onTap,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    if (widget.isRealTime) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E1E1E).withOpacity(0.9),
                    const Color(0xFF2A2A2A).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16.r(context)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: widget.iconColor.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, SpacingSize.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: ResponsiveTextStyles.getCaption(context).copyWith(
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.isRealTime) ...[
                                SizedBox(height: ResponsiveUtils.getSpacing(context, SpacingSize.xs) / 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _pulseAnimation.value,
                                          child: Container(
                                            width: 3.r(context),
                                            height: 3.r(context),
                                            decoration: BoxDecoration(
                                              color: Colors.green[400],
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green[400]!.withOpacity(0.5),
                                                  blurRadius: 2,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(width: ResponsiveUtils.getSpacing(context, SpacingSize.xs) / 3),
                                    Text(
                                      'LIVE',
                                      style: ResponsiveTextStyles.getCaption(context).copyWith(
                                        color: Colors.green[400],
                                        fontSize: 8.sp(context),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, SpacingSize.sm)),
                          decoration: BoxDecoration(
                            color: widget.iconColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8.r(context)),
                            border: Border.all(
                              color: widget.iconColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.iconColor,
                            size: ResponsiveUtils.getIconSize(context, IconSize.md),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, SpacingSize.sm)),
                    Text(
                      widget.value,
                      style: ResponsiveTextStyles.getHeading3(context).copyWith(
                        color: widget.iconColor,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, SpacingSize.xs) / 3),
                    Text(
                      widget.subtitle,
                      style: ResponsiveTextStyles.getCaption(context).copyWith(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}