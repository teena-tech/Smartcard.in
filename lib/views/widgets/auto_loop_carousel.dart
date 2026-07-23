import 'dart:async';
import 'package:flutter/material.dart';

class AutoLoopCarousel extends StatefulWidget {
  final int itemCount;
  final int initialIndex;
  final Widget Function(BuildContext context, int realIndex, int virtualIndex) itemBuilder;
  final Function(int realIndex)? onPageChanged;
  final double viewportFraction;
  final Duration animationDuration;
  final Curve animationCurve;

  final bool autoScroll;

  const AutoLoopCarousel({
    super.key,
    required this.itemCount,
    this.initialIndex = 0,
    required this.itemBuilder,
    this.onPageChanged,
    this.viewportFraction = 1.0,
    this.animationDuration = const Duration(milliseconds: 500),
    this.animationCurve = Curves.easeInOut,
    this.autoScroll = true,
  });

  @override
  State<AutoLoopCarousel> createState() => _AutoLoopCarouselState();
}

class _AutoLoopCarouselState extends State<AutoLoopCarousel> {
  late PageController _pageController;
  late int _virtualPage;
  static const int _multiplier = 10000;

  Timer? _autoPlayTimer;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _initController();
    if (widget.autoScroll) {
      _startAutoPlay();
    }
  }

  void _initController() {
    if (widget.itemCount > 0) {
      _virtualPage = (_multiplier ~/ 2) * widget.itemCount + widget.initialIndex;
    } else {
      _virtualPage = 0;
    }
    _pageController = PageController(
      initialPage: _virtualPage,
      viewportFraction: widget.viewportFraction,
    );
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (!widget.autoScroll) return; // Safety guard
    if (widget.itemCount <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients && widget.itemCount > 0) {
        final nextPage = _pageController.page!.round() + 1;
        _pageController.animateToPage(
          nextPage,
          duration: widget.animationDuration,
          curve: widget.animationCurve,
        );
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
  }

  void _resetInactivityTimer() {
    if (!widget.autoScroll) return;
    _stopAutoPlay();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 30), () {
      _startAutoPlay();
    });
  }

  @override
  void didUpdateWidget(covariant AutoLoopCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If autoScroll was turned off, kill any running timer immediately
    if (!widget.autoScroll) {
      _autoPlayTimer?.cancel();
      _autoPlayTimer = null;
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
    }

    if (oldWidget.itemCount != widget.itemCount) {
      _initController();
      if (widget.autoScroll) {
        _startAutoPlay();
      }
    } else if (oldWidget.initialIndex != widget.initialIndex) {
      final currentRealIndex = _virtualPage % widget.itemCount;
      if (currentRealIndex != widget.initialIndex) {
        _initController();
      }
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _inactivityTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is UserScrollNotification) {
          _resetInactivityTimer();
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        physics: const PageScrollPhysics(),
        onPageChanged: (virtualPage) {
          _virtualPage = virtualPage;
          final realIndex = virtualPage % widget.itemCount;
          if (widget.onPageChanged != null) widget.onPageChanged!(realIndex);
        },
        itemBuilder: (context, virtualIndex) {
          final realIndex = virtualIndex % widget.itemCount;
          return widget.itemBuilder(context, realIndex, virtualIndex);
        },
      ),
    );
  }
}
