// Pure Dart — no Flutter imports
import 'enums.dart';

enum QuestStatus { offered, active, completed, failed }

/// The engine-verifiable objective vocabulary. New template families
/// (bounty, smuggle, escort...) extend this enum; the engine must be able
/// to check completion for every member.
enum QuestTemplate { delivery }

/// A quest with stakes locked at generation time. The narrative fields
/// (title, hook, giverName, resolution texts) are canned templates today
/// and LLM-generated later — the engine never reads them, only the typed
/// objective fields.
class Quest {
  final String id;
  final QuestTemplate template;
  final QuestStatus status;

  // Narrative layer (display only — swap for LLM output later).
  final String title;
  final String hook;
  final String giverName;
  final String successText;
  final String failureText;

  // Objective (engine-enforced).
  final TradeGood good;
  final int qty;
  final int targetSystemIndex;
  final int deadlineDay;

  // Stakes (locked at generation — the narrator can't move the goalposts).
  final int rewardCredits;
  final int rewardRecordBonus; // e.g. a fixer laundering your record
  final int failRecordPenalty;
  final int failReputationPenalty;

  const Quest({
    required this.id,
    required this.template,
    required this.status,
    required this.title,
    required this.hook,
    required this.giverName,
    required this.successText,
    required this.failureText,
    required this.good,
    required this.qty,
    required this.targetSystemIndex,
    required this.deadlineDay,
    required this.rewardCredits,
    this.rewardRecordBonus = 0,
    required this.failRecordPenalty,
    required this.failReputationPenalty,
  });

  Quest copyWith({QuestStatus? status}) {
    return Quest(
      id: id,
      template: template,
      status: status ?? this.status,
      title: title,
      hook: hook,
      giverName: giverName,
      successText: successText,
      failureText: failureText,
      good: good,
      qty: qty,
      targetSystemIndex: targetSystemIndex,
      deadlineDay: deadlineDay,
      rewardCredits: rewardCredits,
      rewardRecordBonus: rewardRecordBonus,
      failRecordPenalty: failRecordPenalty,
      failReputationPenalty: failReputationPenalty,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'template': template.index,
        'status': status.index,
        'title': title,
        'hook': hook,
        'giverName': giverName,
        'successText': successText,
        'failureText': failureText,
        'good': good.index,
        'qty': qty,
        'targetSystemIndex': targetSystemIndex,
        'deadlineDay': deadlineDay,
        'rewardCredits': rewardCredits,
        'rewardRecordBonus': rewardRecordBonus,
        'failRecordPenalty': failRecordPenalty,
        'failReputationPenalty': failReputationPenalty,
      };

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
        id: json['id'] as String,
        template: QuestTemplate.values[json['template'] as int],
        status: QuestStatus.values[json['status'] as int],
        title: json['title'] as String,
        hook: json['hook'] as String,
        giverName: json['giverName'] as String,
        successText: json['successText'] as String,
        failureText: json['failureText'] as String,
        good: TradeGood.values[json['good'] as int],
        qty: json['qty'] as int,
        targetSystemIndex: json['targetSystemIndex'] as int,
        deadlineDay: json['deadlineDay'] as int,
        rewardCredits: json['rewardCredits'] as int,
        rewardRecordBonus: (json['rewardRecordBonus'] ?? 0) as int,
        failRecordPenalty: json['failRecordPenalty'] as int,
        failReputationPenalty: json['failReputationPenalty'] as int,
      );
}
