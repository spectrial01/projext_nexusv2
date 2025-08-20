import 'package:flutter/material.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360 || screenHeight < 640;
    final isVerySmallScreen = screenWidth < 320;
    
    // Adaptive sizing
    final cardPadding = isVerySmallScreen ? 12.0 : isSmallScreen ? 14.0 : 16.0;
    final titleFontSize = isVerySmallScreen ? 10.0 : isSmallScreen ? 11.0 : 12.0;
    final valueFontSize = isVerySmallScreen ? 18.0 : isSmallScreen ? 20.0 : 22.0;
    final subtitleFontSize = isVerySmallScreen ? 8.0 : isSmallScreen ? 9.0 : 10.0;
    final iconSize = isVerySmallScreen ? 16.0 : isSmallScreen ? 18.0 : 20.0;
    final iconPadding = isVerySmallScreen ? 6.0 : isSmallScreen ? 7.0 : 8.0;
    final indicatorSize = isVerySmallScreen ? 3.0 : 4.0;
    final spacing = isVerySmallScreen ? 8.0 : isSmallScreen ? 10.0 : 12.0;
    
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
                borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : 16),
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
                padding: EdgeInsets.all(cardPadding),
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
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.isRealTime) ...[
                                SizedBox(height: spacing / 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _pulseAnimation.value,
                                          child: Container(
                                            width: indicatorSize,
                                            height: indicatorSize,
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
                                    SizedBox(width: spacing / 3),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.green[400],
                                        fontSize: subtitleFontSize - 1,
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
                          padding: EdgeInsets.all(iconPadding),
                          decoration: BoxDecoration(
                            color: widget.iconColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(isVerySmallScreen ? 6 : 8),
                            border: Border.all(
                              color: widget.iconColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.iconColor,
                            size: iconSize,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing),
                    Text(
                      widget.value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                        color: widget.iconColor,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing / 6),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: subtitleFontSize,
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