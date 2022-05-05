part of easyrefresh;

/// EasyRefresh child builder.
/// Provide [ScrollPhysics], and use it in your [ScrollView].
/// [ScrollPhysics] will not be scoped.
typedef ERChildBuilder = Widget Function(
    BuildContext context, ScrollPhysics physics);

/// EasyRefresh needs to share data
class EasyRefreshData {
  /// Header status data and responsive
  final HeaderNotifier headerNotifier;

  /// Footer status data and responsive
  final FooterNotifier footerNotifier;

  /// Whether the user scrolls and responsive
  final ValueNotifier<bool> userOffsetNotifier;

  const EasyRefreshData({
    required this.headerNotifier,
    required this.footerNotifier,
    required this.userOffsetNotifier,
  });
}

class _InheritedEasyRefresh extends InheritedWidget {
  final EasyRefreshData data;

  const _InheritedEasyRefresh({
    Key? key,
    required this.data,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  bool updateShouldNotify(covariant _InheritedEasyRefresh oldWidget) =>
      data != oldWidget.data;
}

class EasyRefresh extends StatefulWidget {
  /// Try to avoid including multiple ScrollViews.
  /// Or set separate ScrollPhysics for other ScrollView.
  /// Otherwise use [EasyRefresh.builder].
  final Widget? child;

  /// EasyRefresh controller.
  final EasyRefreshController? controller;

  /// Header indicator.
  final Header? header;

  /// Footer indicator.
  final Footer? footer;

  /// Overscroll behavior when [onRefresh] is null.
  /// Won't build widget.
  final NotRefreshHeader? notRefreshHeader;

  /// Overscroll behavior when [onLoad] is null.
  /// Won't build widget.
  final NotLoadFooter? notLoadFooter;

  /// EasyRefresh child builder.
  /// Provide [ScrollPhysics], and use it in your [ScrollView].
  /// [ScrollPhysics] will not be scoped.
  final ERChildBuilder? childBuilder;

  /// Refresh callback.
  /// Triggered on refresh.
  /// The Header current state is [IndicatorMode.processing].
  /// More link [IndicatorNotifier.onTask].
  final FutureOr Function()? onRefresh;

  /// Load callback.
  /// Triggered on load.
  /// The Footer current state is [IndicatorMode.processing].
  /// More link [IndicatorNotifier.onTask].
  final FutureOr Function()? onLoad;

  /// Structure that describes a spring's constants.
  /// When spring is not set in [Header] and [Footer].
  final SpringDescription? spring;

  /// Friction factor when list is out of bounds.
  final FrictionFactor? frictionFactor;

  /// Refresh and load can be performed simultaneously.
  final bool simultaneously;

  /// Is it possible to refresh after there is no more.
  final bool noMoreRefresh;

  /// Is it loadable after no more.
  final bool noMoreLoad;

  /// Reset after refresh when no more deactivation is loaded.
  final bool resetAfterRefresh;

  /// Refresh on start.
  /// When the EasyRefresh build is complete, trigger the refresh.
  final bool refreshOnStart;

  /// Header for refresh on start.
  /// Use [header] when null.
  final BuilderHeader? refreshOnStartHeader;

  /// Offset beyond trigger offset when calling refresh.
  /// Used when refreshOnStart is true and [EasyRefreshController.callRefresh].
  final double callRefreshOverOffset;

  /// Offset beyond trigger offset when calling load.
  /// Used when [EasyRefreshController.callLoad].
  final double callLoadOverOffset;

  /// Default header indicator.
  static Header get _defaultHeader => defaultHeaderBuilder.call();
  static Header Function() defaultHeaderBuilder = _defaultHeaderBuilder;

  static Header _defaultHeaderBuilder() => const ClassicalHeader();

  /// Default footer indicator.
  static Footer get _defaultFooter => defaultFooterBuilder.call();
  static Footer Function() defaultFooterBuilder = _defaultFooterBuilder;

  static Footer _defaultFooterBuilder() => const ClassicalFooter();

  const EasyRefresh({
    Key? key,
    required this.child,
    this.controller,
    this.header,
    this.footer,
    this.onRefresh,
    this.onLoad,
    this.spring,
    this.frictionFactor,
    this.notRefreshHeader,
    this.notLoadFooter,
    this.simultaneously = false,
    this.noMoreRefresh = false,
    this.noMoreLoad = false,
    this.resetAfterRefresh = true,
    this.refreshOnStart = false,
    this.refreshOnStartHeader,
    this.callRefreshOverOffset = 20,
    this.callLoadOverOffset = 20,
  })  : childBuilder = null,
        assert(callRefreshOverOffset > 0,
            'callRefreshOverOffset must be greater than 0.'),
        assert(callLoadOverOffset > 0,
            'callLoadOverOffset must be greater than 0.'),
        super(key: key);

  const EasyRefresh.builder({
    Key? key,
    required this.childBuilder,
    this.controller,
    this.header,
    this.footer,
    this.onRefresh,
    this.onLoad,
    this.spring,
    this.frictionFactor,
    this.notRefreshHeader,
    this.notLoadFooter,
    this.simultaneously = false,
    this.noMoreRefresh = false,
    this.noMoreLoad = false,
    this.resetAfterRefresh = true,
    this.refreshOnStart = false,
    this.refreshOnStartHeader,
    this.callRefreshOverOffset = 20,
    this.callLoadOverOffset = 20,
  })  : child = null,
        assert(callRefreshOverOffset > 0,
            'callRefreshOverOffset must be greater than 0.'),
        assert(callLoadOverOffset > 0,
            'callLoadOverOffset must be greater than 0.'),
        super(key: key);

  @override
  _EasyRefreshState createState() => _EasyRefreshState();

  static EasyRefreshData of(BuildContext context) {
    final inheritedEasyRefresh =
        context.dependOnInheritedWidgetOfExactType<_InheritedEasyRefresh>();
    assert(inheritedEasyRefresh != null,
        'Please use it in the scope of EasyRefresh!');
    return inheritedEasyRefresh!.data;
  }
}

class _EasyRefreshState extends State<EasyRefresh>
    with TickerProviderStateMixin {
  /// [ScrollPhysics] use it in EasyRefresh.
  late _ERScrollPhysics _physics;

  /// Needs to share data.
  late EasyRefreshData _data;

  /// User triggered notifier.
  /// Record user triggers and releases.
  ValueNotifier<bool> get _userOffsetNotifier => _data.userOffsetNotifier;

  /// Header indicator notifier.
  HeaderNotifier get _headerNotifier => _data.headerNotifier;

  /// Footer indicator notifier.
  FooterNotifier get _footerNotifier => _data.footerNotifier;

  /// Whether the current is refresh on start.
  bool _isRefreshOnStart = false;

  /// Indicator waiting for refresh task to complete.
  bool get _waitRefreshResult =>
      !(widget.controller?.controlFinishRefresh ?? false);

  /// Indicator waiting for load task to complete.
  bool get _waitLoadResult => !(widget.controller?.controlFinishLoad ?? false);

  /// Use [EasyRefresh._defaultHeader] without [EasyRefresh.header].
  /// Use [NotRefreshHeader] when [EasyRefresh.onRefresh] is null.
  Header get _header {
    if (widget.onRefresh == null) {
      if (widget.notRefreshHeader != null) {
        return widget.notRefreshHeader!;
      } else {
        final h = widget.header ?? EasyRefresh._defaultHeader;
        return NotRefreshHeader(
          clamping: h.clamping,
          spring: h.spring,
          frictionFactor: h.frictionFactor,
        );
      }
    } else {
      Header h = widget.header ?? EasyRefresh._defaultHeader;
      if (_isRefreshOnStart) {
        h = widget.refreshOnStartHeader ?? h;
      }
      return h;
    }
  }

  /// Use [EasyRefresh._defaultFooter] without [EasyRefresh.footer].
  /// Use [NotLoadFooter] when [EasyRefresh.onLoad] is null.
  Footer get _footer {
    if (widget.onLoad == null) {
      if (widget.notLoadFooter != null) {
        return widget.notLoadFooter!;
      } else {
        final f = widget.footer ?? EasyRefresh._defaultFooter;
        return NotLoadFooter(
          clamping: f.clamping,
          spring: f.spring,
          frictionFactor: f.frictionFactor,
        );
      }
    } else {
      return widget.footer ?? EasyRefresh._defaultFooter;
    }
  }

  @override
  void initState() {
    super.initState();
    // Refresh on start.
    if (widget.refreshOnStart && widget.onRefresh != null) {
      _isRefreshOnStart = true;
      Future(() {
        _callRefresh(widget.callRefreshOverOffset);
      });
    }
    _initData();
    widget.controller?._bind(this);
  }

  @override
  void didUpdateWidget(covariant EasyRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update header and footer.
    _headerNotifier._update(
      indicator: _header,
      noMoreProcess: widget.noMoreRefresh,
      task: _onRefresh,
      waitTaskRefresh: _waitRefreshResult,
    );
    _footerNotifier._update(
      indicator: _footer,
      noMoreProcess: widget.noMoreLoad,
      task: widget.onLoad,
      waitTaskRefresh: _waitLoadResult,
    );
    // Update controller.
    if (widget.controller != null &&
        oldWidget.controller != widget.controller) {
      widget.controller?._bind(this);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _headerNotifier.dispose();
    _footerNotifier.dispose();
    _userOffsetNotifier.dispose();
  }

  /// Initialize [EasyRefreshData].
  void _initData() {
    final userOffsetNotifier = ValueNotifier<bool>(false);
    _data = EasyRefreshData(
      userOffsetNotifier: userOffsetNotifier,
      headerNotifier: HeaderNotifier(
        header: _header,
        userOffsetNotifier: userOffsetNotifier,
        vsync: this,
        onRefresh: _onRefresh,
        noMoreRefresh: widget.noMoreRefresh,
        waitRefreshResult: _waitRefreshResult,
        onCanRefresh: () {
          if (widget.simultaneously) {
            return true;
          } else {
            return !_footerNotifier._processing;
          }
        },
      ),
      footerNotifier: FooterNotifier(
        footer: _footer,
        userOffsetNotifier: userOffsetNotifier,
        vsync: this,
        onLoad: widget.onLoad,
        noMoreLoad: widget.noMoreLoad,
        waitLoadResult: _waitLoadResult,
        onCanLoad: () {
          if (widget.simultaneously) {
            return true;
          } else {
            return !_headerNotifier._processing;
          }
        },
      ),
    );
    _physics = _ERScrollPhysics(
      userOffsetNotifier: _userOffsetNotifier,
      headerNotifier: _headerNotifier,
      footerNotifier: _footerNotifier,
      spring: widget.spring,
      frictionFactor: widget.frictionFactor,
    );
  }

  /// Refresh on start listener.
  /// From [IndicatorMode.processing] to [IndicatorMode.inactive].
  /// When back to inactive, end listening.
  void _refreshOnStartListener() {
    if (_headerNotifier._mode == IndicatorMode.inactive) {
      _isRefreshOnStart = false;
      _headerNotifier.removeListener(_refreshOnStartListener);
      _headerNotifier._update(
        indicator: _header,
        task: _onRefresh,
      );
    }
  }

  /// Refresh callback.
  /// Handle [EasyRefresh.resetAfterRefresh].
  FutureOr Function()? get _onRefresh {
    if (widget.onRefresh == null) {
      return null;
    }
    return () async {
      // Start listening on refresh.
      if (_isRefreshOnStart) {
        _headerNotifier.addListener(_refreshOnStartListener);
      }
      final res = await Future.sync(widget.onRefresh!);
      // Reset Footer state.
      if (widget.resetAfterRefresh) {
        _footerNotifier._reset();
      }
      return res;
    };
  }

  /// Automatically trigger refresh.
  /// [overOffset] Offset beyond the trigger offset, must be greater than 0.
  void _callRefresh([double? overOffset]) {
    _headerNotifier.callTask(overOffset ?? widget.callRefreshOverOffset);
  }

  /// Automatically trigger load.
  /// [overOffset] Offset beyond the trigger offset, must be greater than 0.
  void _callLoad([double? overOffset]) {
    _headerNotifier.callTask(overOffset ?? widget.callLoadOverOffset);
  }

  /// Build Header widget.
  /// When the Header [Indicator.position] is
  /// [IndicatorPosition.above] or [IndicatorPosition.above].
  Widget _buildHeaderView() {
    return ValueListenableBuilder(
      valueListenable: _headerNotifier.listenable(),
      builder: (ctx, notifier, _) {
        // Physics is not initialized.
        if (_headerNotifier.axis == null ||
            _headerNotifier.axisDirection == null) {
          return const SizedBox();
        }
        // Axis and direction.
        final axis = _headerNotifier.axis!;
        final axisDirection = _headerNotifier.axisDirection!;
        // Set safe area offset.
        final safePadding = MediaQuery.of(context).padding;
        _headerNotifier._safeOffset = axis == Axis.vertical
            ? axisDirection == AxisDirection.down
                ? safePadding.top
                : safePadding.bottom
            : axisDirection == AxisDirection.right
                ? safePadding.left
                : safePadding.right;
        return Positioned(
          top: axis == Axis.vertical
              ? axisDirection == AxisDirection.down
                  ? 0
                  : null
              : 0,
          bottom: axis == Axis.vertical
              ? axisDirection == AxisDirection.up
                  ? 0
                  : null
              : 0,
          left: axis == Axis.horizontal
              ? axisDirection == AxisDirection.right
                  ? 0
                  : null
              : 0,
          right: axis == Axis.horizontal
              ? axisDirection == AxisDirection.left
                  ? 0
                  : null
              : 0,
          child: _headerNotifier._build(context),
        );
      },
    );
  }

  /// Build Footer widget.
  /// When the Footer [Indicator.position] is
  /// [IndicatorPosition.above] or [IndicatorPosition.above].
  Widget _buildFooterView() {
    return ValueListenableBuilder(
      valueListenable: _footerNotifier.listenable(),
      builder: (ctx, notifier, _) {
        // Physics is not initialized.
        if (_headerNotifier.axis == null ||
            _headerNotifier.axisDirection == null) {
          return const SizedBox();
        }
        // Axis and direction.
        final axis = _headerNotifier.axis!;
        final axisDirection = _headerNotifier.axisDirection!;
        // Set safe area offset.
        final safePadding = MediaQuery.of(context).padding;
        _footerNotifier._safeOffset = axis == Axis.vertical
            ? axisDirection == AxisDirection.down
                ? safePadding.bottom
                : safePadding.top
            : axisDirection == AxisDirection.right
                ? safePadding.right
                : safePadding.left;
        return Positioned(
          top: axis == Axis.vertical
              ? axisDirection == AxisDirection.up
                  ? 0
                  : null
              : 0,
          bottom: axis == Axis.vertical
              ? axisDirection == AxisDirection.down
                  ? 0
                  : null
              : 0,
          left: axis == Axis.horizontal
              ? axisDirection == AxisDirection.left
                  ? 0
                  : null
              : 0,
          right: axis == Axis.horizontal
              ? axisDirection == AxisDirection.right
                  ? 0
                  : null
              : 0,
          child: _footerNotifier._build(context),
        );
      },
    );
  }

  /// Build content widget.
  Widget _buildContent() {
    Widget child;
    if (widget.childBuilder != null) {
      child = ScrollConfiguration(
        behavior: const _ERScrollBehavior(),
        child: widget.childBuilder!(context, _physics),
      );
    } else {
      child = ScrollConfiguration(
        behavior: _ERScrollBehavior(_physics),
        child: widget.child!,
      );
    }
    return _InheritedEasyRefresh(
      data: _data,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentWidget = _buildContent();
    final List<Widget> children = [];
    final hPosition = _headerNotifier.iPosition;
    final fPosition = _footerNotifier.iPosition;
    // Set safe area offset.
    // final safePadding = MediaQuery.of(context).padding;
    // if (hPosition != IndicatorPosition.locator) {
    //   _headerNotifier._safeOffset = safePadding.top;
    // }
    // if (fPosition != IndicatorPosition.locator) {
    //   _footerNotifier._safeOffset = safePadding.bottom;
    // }
    // Set the position of widgets.
    if (hPosition == IndicatorPosition.behind) {
      children.add(_buildHeaderView());
    }
    if (fPosition == IndicatorPosition.behind) {
      children.add(_buildFooterView());
    }
    children.add(contentWidget);
    if (hPosition == IndicatorPosition.above) {
      children.add(_buildHeaderView());
    }
    if (fPosition == IndicatorPosition.above) {
      children.add(_buildFooterView());
    }
    if (children.length == 1) {
      children.clear();
      return contentWidget;
    }
    return Stack(
      fit: StackFit.expand,
      children: children,
    );
  }
}
