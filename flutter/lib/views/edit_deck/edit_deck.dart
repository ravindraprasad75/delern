import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:delern_flutter/flutter/localization.dart' as localizations;
import 'package:delern_flutter/flutter/styles.dart' as app_styles;
import 'package:delern_flutter/flutter/user_messages.dart';
import 'package:delern_flutter/models/card_model.dart';
import 'package:delern_flutter/models/deck_access_model.dart';
import 'package:delern_flutter/models/deck_model.dart';
import 'package:delern_flutter/routes.dart';
import 'package:delern_flutter/view_models/edit_deck_bloc.dart';
import 'package:delern_flutter/views/base/screen_bloc_view.dart';
import 'package:delern_flutter/views/edit_deck/deck_settings_widget.dart';
import 'package:delern_flutter/views/edit_deck/scroll_to_beginning_list_widget.dart';
import 'package:delern_flutter/views/helpers/arrow_to_fab_widget.dart';
import 'package:delern_flutter/views/helpers/card_background_specifier.dart';
import 'package:delern_flutter/views/helpers/edit_delete_dismissible_widget.dart';
import 'package:delern_flutter/views/helpers/empty_list_message_widget.dart';
import 'package:delern_flutter/views/helpers/list_accessor_widget.dart';
import 'package:delern_flutter/views/helpers/search_bar_widget.dart';
import 'package:delern_flutter/views/helpers/stream_with_value_builder.dart';
import 'package:delern_flutter/views/helpers/text_overflow_ellipsis_widget.dart';
import 'package:flutter/material.dart';

const int _kUpButtonVisibleRow = 20;
const double _kDividerPadding = 12;

class EditDeck extends StatefulWidget {
  static const routeName = '/cards';

  static Map<String, String> buildArguments({
    @required String deckKey,
  }) =>
      {
        'deckKey': deckKey,
      };

  const EditDeck() : super();

  @override
  _EditDeckState createState() => _EditDeckState();
}

class _EditDeckState extends State<EditDeck> {
  final TextEditingController _deckNameController = TextEditingController();
  DeckModel _currentDeckState;
  GlobalKey fabKey = GlobalKey();

  void _searchTextChanged(EditDeckBloc bloc, String input) {
    if (input == null) {
      bloc.filter = null;
      return;
    }
    input = input.toLowerCase();
    bloc.filter = (c) =>
        c.front.toLowerCase().contains(input) ||
        c.back.toLowerCase().contains(input);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> arguments =
        ModalRoute.of(context).settings.arguments;
    return ScreenBlocView<EditDeckBloc>(
      blocBuilder: (user) {
        final bloc = EditDeckBloc(
          deckKey: arguments['deckKey'],
          user: user,
        );
        _currentDeckState = bloc.deck;
        _deckNameController.text = _currentDeckState.name;
        bloc.doDeckChanged.listen((deck) {
          setState(() {
            _currentDeckState = deck;
          });
        });
        bloc.doEditCard.listen((card) {
          openEditCardScreen(
            context,
            deckKey: card.deckKey,
            cardKey: card.key,
          );
        });

        return bloc;
      },
      appBarBuilder: (bloc) => SearchBarWidget(
        title: localizations.of(context).edit,
        search: (input) => _searchTextChanged(bloc, input),
        actions: _buildActions(bloc),
      ),
      bodyBuilder: (bloc) => Column(
        children: <Widget>[
          _buildEditDeck(bloc),
          _buildCardsInDeck(bloc),
          const Padding(
            padding: EdgeInsets.only(bottom: _kDividerPadding),
          ),
          const Divider(
            height: 0,
          ),
          Expanded(child: _buildCardList(bloc)),
        ],
      ),
      floatingActionButtonBuilder: _buildAddCard,
    );
  }

  List<Widget> _buildActions(EditDeckBloc bloc) {
    final menuAction = IconButton(
      tooltip: localizations.of(context).deckSettingsTooltip,
      icon: Icon(Icons.more_vert),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (context) => Dialog(
              child: DeckSettingsWidget(deck: _currentDeckState, bloc: bloc)),
        );
      },
    );

    return <Widget>[menuAction];
  }

  Widget _buildEditDeck(EditDeckBloc bloc) => TextField(
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: InputBorder.none,
          suffixIcon: const Icon(Icons.edit),
          // We'd like to center text. Because of suffixIcon, the text
          // is placed a little bit to the left. To fix this problem, we
          // add an empty Container with size of Icon to the left.
          prefixIcon: Container(
            height: IconTheme.of(context).size,
            width: IconTheme.of(context).size,
          ),
        ),
        maxLines: null,
        keyboardType: TextInputType.multiline,
        controller: _deckNameController,
        style: app_styles.editDeckText,
        onChanged: bloc.onDeckName.add,
      );

  Widget _buildCardsInDeck(EditDeckBloc bloc) =>
      buildStreamBuilderWithValue<BuiltList<CardModel>>(
          streamWithValue: bloc.list,
          builder: (context, snapshot) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    localizations
                        .of(context)
                        .numberOfCards(snapshot.data.length),
                    style: app_styles.secondaryText,
                  ),
                ],
              ));

  Widget _buildCardList(EditDeckBloc bloc) {
    final cardVerticalPadding =
        MediaQuery.of(context).size.height * app_styles.kItemListPaddingRatio;
    return ScrollToBeginningListWidget(
      builder: (controller) => ListAccessorWidget<CardModel>(
        list: bloc.list,
        itemBuilder: (context, item, index) {
          final card = _buildCardItem(item, cardVerticalPadding, bloc);
          if (index == 0) {
            return Padding(
              // Space between 1st element and border must be 2 times indent
              // between elements. Space between 2 elem = 2*cardVerticalPadding
              // 1st indent is at the end of 1st elem, 2nd indent is at
              // the beginning 2d element. 2 times more == 4*cardVerticalPadding
              // we have already 1 indent at the beginning. Therefore
              // we need 3 extra
              padding: EdgeInsets.only(top: 3 * cardVerticalPadding),
              child: card,
            );
          } else {
            return card;
          }
        },
        emptyMessageBuilder: () => ArrowToFloatingActionButtonWidget(
          fabKey: fabKey,
          child:
              EmptyListMessageWidget(localizations.of(context).emptyCardsList),
        ),
        controller: controller,
      ),
      minItemHeight: app_styles.kMinItemHeight + 2 * cardVerticalPadding,
      upButtonVisibleRow: _kUpButtonVisibleRow,
    );
  }

  Column _buildCardItem(
    CardModel item,
    double verticalPadding,
    EditDeckBloc bloc,
  ) =>
      Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: verticalPadding),
            child: CardItemWidget(
              card: item,
              deck: _currentDeckState,
              bloc: bloc,
            ),
          ),
        ],
      );

  Widget _buildAddCard(EditDeckBloc bloc) => Builder(
        builder: (context) => FloatingActionButton(
          tooltip: localizations.of(context).addCardTooltip,
          key: fabKey,
          onPressed: () {
            if (_currentDeckState.access != AccessType.read) {
              openNewCardScreen(context, deckKey: _currentDeckState.key);
            } else {
              UserMessages.showMessage(Scaffold.of(context),
                  localizations.of(context).noAddingWithReadAccessUserMessage);
            }
          },
          child: const Icon(Icons.add),
        ),
      );
}

const double _kCardBorderPadding = 16;
const double _kFrontBackTextPadding = 5;

class CardItemWidget extends StatelessWidget {
  final CardModel card;
  final DeckModel deck;
  final EditDeckBloc bloc;

  const CardItemWidget({
    @required this.card,
    @required this.deck,
    @required this.bloc,
  })  : assert(card != null),
        assert(deck != null),
        assert(bloc != null);

  @override
  Widget build(BuildContext context) {
    final emptyExpanded = Expanded(
      flex: 1,
      child: Container(
        color: Colors.transparent,
      ),
    );

    final minHeight = max(
        MediaQuery.of(context).size.height * app_styles.kItemListHeightRatio,
        app_styles.kMinItemHeight);
    final primaryFontSize =
        max(minHeight * 0.25, app_styles.kMinPrimaryTextSize);
    final primaryTextStyle =
        app_styles.editCardPrimaryText.copyWith(fontSize: primaryFontSize);
    final secondaryTextStyle = app_styles.editCardSecondaryText
        .copyWith(fontSize: primaryFontSize / 1.5);
    final iconSize = max(minHeight * 0.5, app_styles.kMinIconHeight);
    return Row(
      children: <Widget>[
        emptyExpanded,
        Expanded(
          flex: 8,
          child: EditDeleteDismissible(
            key: Key(card.key),
            iconSize: iconSize,
            onEdit: () => bloc.onEditCardIntention.add(card),
            child: Material(
              elevation: app_styles.kItemElevation,
              child: InkWell(
                splashColor: Theme.of(context).splashColor,
                onTap: () => openPreviewCardScreen(
                  context,
                  deckKey: deck.key,
                  cardKey: card.key,
                ),
                child: Container(
                  padding: const EdgeInsets.all(_kCardBorderPadding),
                  decoration: BoxDecoration(
                    gradient: specifyEditCardBackgroundGradient(
                      deck.type,
                      card.back,
                    ),
                  ),
                  // Use row to expand content to all available space
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            TextOverflowEllipsisWidget(
                              textDetails: card.frontWithoutTags,
                              textStyle: primaryTextStyle,
                            ),
                            Container(
                              padding: const EdgeInsets.only(
                                  top: _kFrontBackTextPadding),
                              child: TextOverflowEllipsisWidget(
                                textDetails: card.back ?? '',
                                textStyle: secondaryTextStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        emptyExpanded,
      ],
    );
  }
}
