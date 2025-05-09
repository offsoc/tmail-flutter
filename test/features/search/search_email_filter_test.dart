import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/core/filter/filter_operator.dart';
import 'package:jmap_dart_client/jmap/core/filter/operator/logic_filter_operator.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/utc_date.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_filter_condition.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/search/email_receive_time_type.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/search/email_sort_order_type.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/search/search_email_filter.dart';
import 'package:tmail_ui_user/features/thread/domain/model/search_query.dart';

void main() {
  group('SearchEmailFilter::test', () {
    group('generateFilterFromToField::test', () {
      late SearchEmailFilter searchEmailFilter;

      setUp(() {
        searchEmailFilter = SearchEmailFilter();
      });

      test('SHOULD generate a single filter WHEN "to" has one item', () {
        // Arrange
        searchEmailFilter = SearchEmailFilter(
          to: {'singleRecipient@example.com'},
        );

        // Act
        final filters = searchEmailFilter.generateFilterFromToField();

        // Assert
        expect(filters.length, 1);

        expect(filters.first, isA<LogicFilterOperator>());

        final filter = filters.first as LogicFilterOperator;
        expect(filter.operator, Operator.OR);

        expect(filter.conditions, {
          EmailFilterCondition(to: 'singleRecipient@example.com'),
          EmailFilterCondition(cc: 'singleRecipient@example.com'),
          EmailFilterCondition(bcc: 'singleRecipient@example.com'),
        });
      });

      test('SHOULD generate multiple from filters which combine with OR operator WHEN "to" has multiple items', () {
        // Arrange
        searchEmailFilter = SearchEmailFilter(
          to: {'recipient1@example.com', 'recipient2@example.com'},
        );

        // Act
        final filters = searchEmailFilter.generateFilterFromToField();

        // Assert
        expect(filters.length, 2);

        expect(filters[0], isA<LogicFilterOperator>());
        expect(filters[1], isA<LogicFilterOperator>());

        final filter1 = filters[0] as LogicFilterOperator;
        expect(filter1.operator, Operator.OR);
        expect(filter1.conditions, {
          EmailFilterCondition(to: 'recipient1@example.com'),
          EmailFilterCondition(cc: 'recipient1@example.com'),
          EmailFilterCondition(bcc: 'recipient1@example.com'),
        });

        final filter2 = filters[1] as LogicFilterOperator;
        expect(filter2.operator, Operator.OR);
        expect(filter2.conditions, {
          EmailFilterCondition(to: 'recipient2@example.com'),
          EmailFilterCondition(cc: 'recipient2@example.com'),
          EmailFilterCondition(bcc: 'recipient2@example.com'),
        });
      });
    });

    group('mappingToEmailFilterCondition::test', () {
      test('SHOULD returns null WHEN there are no conditions', () {
        // Arrange
        final filter = SearchEmailFilter.initial();

        // Act
        final result = filter.mappingToEmailFilterCondition();

        // Assert
        expect(result, isNull);
      });

      test('SHOULD creates a simple filter WHEN text is provided', () {
        // Arrange
        final filter = SearchEmailFilter(
          text: SearchQuery('example'),
        );

        // Act
        final result = filter.mappingToEmailFilterCondition();

        // Assert
        expect(result, isA<EmailFilterCondition>());
        final emailCondition = result as EmailFilterCondition;
        expect(emailCondition.text, 'example');
      });

      test('SHOULD creates a filter with multiple "to" values using AND logic operator', () {
        // Arrange
        final filter = SearchEmailFilter(
          to: {'to1@example.com', 'to2@example.com'},
        );

        // Act
        final result = filter.mappingToEmailFilterCondition();

        // Assert
        expect(result, isA<LogicFilterOperator>());
        final logicOperator = result as LogicFilterOperator;
        expect(logicOperator.operator, Operator.AND);
        expect(logicOperator.conditions.length, equals(2));
      });

      test('SHOULD includes moreFilterCondition WHEN provided', () {
        // Arrange
        final moreCondition = EmailFilterCondition(text: 'moreFilter');
        final filter = SearchEmailFilter(
          text: SearchQuery('example'),
        );

        // Act
        final result = filter.mappingToEmailFilterCondition(moreFilterCondition: moreCondition);

        // Assert
        expect(result, isA<LogicFilterOperator>());
        final logicOperator = result as LogicFilterOperator;
        expect(logicOperator.conditions.contains(moreCondition), isTrue);
      });

      test('SHOULD combines multiple fields into an AND filter', () {
        // Arrange
        final filter = SearchEmailFilter(
          from: {'sender@example.com'},
          to: {'to@example.com'},
          text: SearchQuery('text'),
          subject: 'subject',
          notKeyword: {'keyword'},
          hasKeyword: {'hasKeyword'},
          mailbox: PresentationMailbox(MailboxId(Id('inbox-id')), name: MailboxName('Inbox')),
          emailReceiveTimeType: EmailReceiveTimeType.last7Days,
          hasAttachment: true,
          before: UTCDate(DateTime.parse('2024-10-30 12:00:00')),
          startDate: UTCDate(DateTime.parse('2024-10-30 12:00:00')),
          endDate: UTCDate(DateTime.parse('2024-10-31 12:00:00')),
          position: 0,
          sortOrderType: EmailSortOrderType.oldest,
        );

        // Act
        final result = filter.mappingToEmailFilterCondition();

        // Assert
        expect(result, isA<LogicFilterOperator>());
        final logicOperator = result as LogicFilterOperator;
        expect(logicOperator.operator, Operator.AND);
        expect(logicOperator.conditions.length, greaterThan(1));
      });

      test('SHOULD wrap a simple EmailFilterCondition inside a NOT LogicFilterOperator when notKeyword is given', () {
        // Arrange
        final filter = SearchEmailFilter(
          notKeyword: {'hello'},
        );

        // Act
        final result = filter.mappingToEmailFilterCondition();

        // Assert
        expect(result, isA<LogicFilterOperator>());
        final logicFilter = result as LogicFilterOperator;
        expect(result.conditions.length, equals(1));
        expect(logicFilter.operator, equals(Operator.NOT));

        final emailCondition = result.conditions.first as EmailFilterCondition;
        expect(emailCondition.text, 'hello');
        expect(emailCondition.notKeyword, isNull);
      });

      test(
        'SHOULD convert the notKeyword set into a NOT LogicFilterOperator containing multiple EmailFilterCondition instances,\n'
        'each representing a keyword from the set',
      () {
        // Arrange
        // Create a SearchEmailFilter with three keywords in the notKeyword field
        final filter = SearchEmailFilter(
          notKeyword: {'hello', 'hi', 'bye'},
        );

        // Act
        // Call mappingToEmailFilterCondition to transform it into filter conditions
        final result = filter.mappingToEmailFilterCondition();

        // Assert
        // The result should be a LogicFilterOperator with the NOT operator
        expect(result, isA<LogicFilterOperator>());
        final logicFilter = result as LogicFilterOperator;
        expect(logicFilter.operator, equals(Operator.NOT));

        // The LogicFilterOperator should contain 3 EmailFilterCondition objects, one for each keyword
        expect(logicFilter.conditions.isNotEmpty, equals(true));
        expect(logicFilter.conditions.length, equals(3));

        // Verify each EmailFilterCondition's content
        final listEmailCondition = logicFilter.conditions.map((e) => e as EmailFilterCondition).toList();

        expect(listEmailCondition[0].text, 'hello');
        expect(listEmailCondition[0].notKeyword, isNull);

        expect(listEmailCondition[1].text, 'hi');
        expect(listEmailCondition[1].notKeyword, isNull);

        expect(listEmailCondition[2].text, 'bye');
        expect(listEmailCondition[2].notKeyword, isNull);
      });
    });
  });
}
