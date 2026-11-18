import 'top_to_bottom_slide_route.dart';

/// Legacy export/alias ensuring all existing navigation uses the top-to-bottom slide & scale animation.
class GenieEffectRoute<T> extends TopToBottomSlideRoute<T> {
  GenieEffectRoute({required super.page, super.settings});
}

typedef CardExpansionPageRoute<T> = TopToBottomSlideRoute<T>;
