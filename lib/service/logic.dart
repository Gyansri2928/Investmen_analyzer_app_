import 'dart:math';

class PropertyCalculator {
  // --- UTILITIES ---
  static double calculateEMI(
    double principal,
    double annualRate,
    double years,
  ) {
    if (principal <= 0 || years <= 0) return 0;
    if (annualRate <= 0) return principal / (years * 12);
    double monthlyRate = annualRate / (12 * 100);
    double months = years * 12;
    return principal *
        monthlyRate *
        pow(1 + monthlyRate, months) /
        (pow(1 + monthlyRate, months) - 1);
  }

  static double calculateOutstanding(
    double principal,
    double annualRate,
    double years,
    double paymentsMade,
  ) {
    if (principal <= 0 || paymentsMade <= 0) return principal;
    double monthlyRate = annualRate / (12 * 100);
    double totalMonths = years * 12;
    if (paymentsMade >= totalMonths) return 0;
    return max(
      0,
      principal *
          (pow(1 + monthlyRate, totalMonths) -
              pow(1 + monthlyRate, paymentsMade)) /
          (pow(1 + monthlyRate, totalMonths) - 1),
    );
  }

  static double calculateTotalInterest(
    double principal,
    double annualRate,
    double years,
    double paymentsMade,
  ) {
    if (principal <= 0 || paymentsMade <= 0) return 0;
    double monthlyRate = annualRate / (12 * 100);
    double emi = calculateEMI(principal, annualRate, years);
    double interestPaid = 0;
    double remainingPrincipal = principal;

    for (int i = 0; i < paymentsMade; i++) {
      if (remainingPrincipal <= 0) break;
      double interestForMonth = remainingPrincipal * monthlyRate;
      double principalForMonth = emi - interestForMonth;
      interestPaid += interestForMonth;
      remainingPrincipal -= principalForMonth;
    }
    return interestPaid;
  }

  static double getSafeValue(dynamic val) {
    return double.tryParse(val.toString()) ?? 0;
  }

  // --- MAIN CALCULATION ---
  static Map<String, dynamic> calculate(
    Map<String, dynamic> data,
    Map<String, dynamic> selections,
  ) {
    // 1. Extract Inputs
    double size = getSafeValue(selections['selectedPropertySize']);
    double purchasePrice = getSafeValue(data['purchasePrice']);
    double otherCharges = getSafeValue(data['otherCharges']);
    double stampDutyPct = getSafeValue(data['stampDuty']);
    double gstPct = getSafeValue(data['gstPercentage']);
    String paymentPlan = data['paymentPlan'] ?? 'clp';
    var assumptions = data['assumptions'];

    // Holding Period
    double yearsInput = getSafeValue(assumptions['investmentPeriod']);
    String unit = assumptions['holdingPeriodUnit'] ?? 'years';
    double totalHoldingMonths = unit == 'months' ? yearsInput : yearsInput * 12;
    double yearsDisplay = totalHoldingMonths / 12;

    double baseCost = size * purchasePrice;
    double agreementValue = baseCost; // Backend logic uses baseCost for taxes
    double stampDutyCost = agreementValue * (stampDutyPct / 100);
    double gstCost = agreementValue * (gstPct / 100);
    double totalCost = baseCost;

    // Loan Shares
    double hlShare = 80, pl1Share = 10, pl2Share = 10, dpShare = 0;
    if (paymentPlan == 'clp') {
      hlShare = 80;
      pl1Share = 10;
      pl2Share = 10;
      dpShare = 0;
    } else if (paymentPlan == '80-20') {
      hlShare = 80;
      pl1Share = 20;
      pl2Share = 0;
      dpShare = 0;
    } else if (paymentPlan == '25-75') {
      hlShare = 75;
      pl1Share = 25;
      pl2Share = 0;
      dpShare = 0;
    } else if (paymentPlan == 'rtm') {
      hlShare = 80;
      pl1Share = 20;
      pl2Share = 0;
      dpShare = 0;
    } else {
      hlShare = getSafeValue(assumptions['homeLoanShare']);
      pl1Share = getSafeValue(assumptions['personalLoan1Share']);
      pl2Share = getSafeValue(assumptions['personalLoan2Share']);
      dpShare = getSafeValue(assumptions['downPaymentShare']);
    }

    double hlAmount = totalCost * (hlShare / 100);
    double pl1Amount = totalCost * (pl1Share / 100);
    double pl2Amount = totalCost * (pl2Share / 100);
    double dpAmount = totalCost * (dpShare / 100);
    double totalCashInvested = dpAmount + pl1Amount + pl2Amount;

    // Rates & Tenures
    double hlRate = getSafeValue(assumptions['homeLoanRate']);
    double hlTerm = getSafeValue(assumptions['homeLoanTerm']);
    double pl1Rate = getSafeValue(assumptions['personalLoan1Rate']);
    double pl1Term = getSafeValue(assumptions['personalLoan1Term']);
    double pl2Rate = getSafeValue(assumptions['personalLoan2Rate']);
    double pl2Term = getSafeValue(assumptions['personalLoan2Term']);

    double hlEMI = calculateEMI(hlAmount, hlRate, hlTerm);
    double pl1EMI = calculateEMI(pl1Amount, pl1Rate, pl1Term);
    double pl2EMI = calculateEMI(pl2Amount, pl2Rate, pl2Term);

    // --- TIMING LOGIC ---
    List props = data['properties'] as List;
    var matchingProps = props.where(
      (p) => p['id'] == selections['selectedPropertyId'],
    );
    var activeProp = matchingProps.isNotEmpty
        ? matchingProps.first
        : (props.isNotEmpty ? props[0] : {});
    double possessionMonths = getSafeValue(
      activeProp['possessionMonths'] ?? 24,
    );

    double lastDemandMonth = possessionMonths;
    if (paymentPlan == 'clp') {
      double explicitLast = getSafeValue(
        assumptions['lastBankDisbursementMonth'],
      );
      double constructionEnd =
          getSafeValue(assumptions['clpDurationYears']) * 12;
      lastDemandMonth = explicitLast > 0
          ? explicitLast
          : (constructionEnd > 0 ? constructionEnd : possessionMonths);
    }

    double hlInputDelay = getSafeValue(assumptions['homeLoanStartMonth']);
    double realHomeLoanStartMonth;
    if (assumptions['homeLoanStartMode'] == 'manual') {
      realHomeLoanStartMonth = hlInputDelay;
    } else {
      realHomeLoanStartMonth = lastDemandMonth + hlInputDelay + 1;
    }

    double pl1StartMonth = getSafeValue(assumptions['personalLoan1StartMonth']);
    double pl2Delay = getSafeValue(assumptions['personalLoan2StartMonth']);
    double pl2StartMonth = possessionMonths + pl2Delay;

    // --- IDC GENERATION ---
    List<Map<String, dynamic>> idcSchedule = [];
    double interval = getSafeValue(assumptions['bankDisbursementInterval']);
    if (interval == 0) interval = 3;
    double startMonth = getSafeValue(assumptions['bankDisbursementStartMonth']);
    if (startMonth == 0) startMonth = 1;

    double fundingEndMonth = lastDemandMonth;

    // Determine Interest Cutoff
    double interestCutoffMonth = possessionMonths;
    if (assumptions['lastBankDisbursementMonth'] != null &&
        getSafeValue(assumptions['lastBankDisbursementMonth']) > 0) {
      interestCutoffMonth = getSafeValue(
        assumptions['lastBankDisbursementMonth'],
      );
    }
    if (assumptions['homeLoanStartMode'] == 'manual' &&
        getSafeValue(assumptions['homeLoanStartMonth']) > 0) {
      interestCutoffMonth = getSafeValue(assumptions['homeLoanStartMonth']) - 1;
    }

    int slabsCount = ((fundingEndMonth - startMonth) / interval).floor() + 1;
    if (slabsCount < 1) slabsCount = 1;
    double slabAmount = hlAmount > 0 ? hlAmount / slabsCount : 0;
    double baseSlabInterest = (slabAmount * (hlRate / 100)) / 12;

    double grandTotalInterest = 0;

    for (int i = 0; i < slabsCount; i++) {
      double m = startMonth + (i * interval);
      if (m <= fundingEndMonth && hlAmount > 0) {
        // Calculate Duration
        double duration = 0;
        if (m <= interestCutoffMonth) {
          duration = max(0, interestCutoffMonth - m + 1);
        }

        double cumulativeMonthlyInterest = baseSlabInterest * (i + 1);
        double totalCostForSlab = baseSlabInterest * duration;
        grandTotalInterest += totalCostForSlab;

        idcSchedule.add({
          'slabNo': i + 1,
          'releaseMonth': m,
          'amount': slabAmount,
          'duration': duration,
          'cumulativeMonthlyInterest': cumulativeMonthlyInterest,
          'totalCostForSlab': totalCostForSlab,
        });
      }
    }

    // --- LEDGER GENERATION ---
    List<Map<String, dynamic>> monthlyLedger = [];
    double cumulativeDisbursement = 0;
    double outstandingBalance = 0;
    double totalIDC = 0;
    double minIDCEMI = 0;
    double maxIDCEMI = 0;
    bool isFirstIDCPayment = false;
    double runningPrePossessionTotal = 0;
    double runningPostPossessionTotal = 0;

    for (int m = 0; m <= possessionMonths; m++) {
      // Ledger usually goes up to possession or holding
      double currentDisbursement = 0;
      double interestForThisMonth = 0;
      double principalRepaidThisMonth = 0;

      // A. Disbursement
      if (paymentPlan == 'clp' && hlAmount > 0 && m <= fundingEndMonth) {
        bool isScheduleMonth = idcSchedule.any((s) => s['releaseMonth'] == m);
        if (isScheduleMonth && cumulativeDisbursement < (hlAmount - 10)) {
          currentDisbursement = slabAmount;
          cumulativeDisbursement += slabAmount;
          if (assumptions['homeLoanStartMode'] == 'manual') {
            outstandingBalance += slabAmount;
          } else {
            outstandingBalance = cumulativeDisbursement;
          }
        }
      }

      // B. Interest
      if (outstandingBalance > 0) {
        interestForThisMonth = (outstandingBalance * (hlRate / 100)) / 12;
      }

      // C. Payment
      double hlPayment = 0;
      bool isFullEMI = false;

      if (hlAmount > 0) {
        if (m >= realHomeLoanStartMonth) {
          hlPayment = hlEMI;
          isFullEMI = true;
          if (outstandingBalance > 0) {
            principalRepaidThisMonth = max(0, hlPayment - interestForThisMonth);
            outstandingBalance -= principalRepaidThisMonth;
          }
        } else {
          if (assumptions['homeLoanStartMode'] == 'manual') {
            hlPayment = 0;
          } else {
            hlPayment = interestForThisMonth;
            principalRepaidThisMonth = 0;
          }

          // Track IDC for summary
          if (m > 0) {
            // Month 0 usually has no interest
            totalIDC += interestForThisMonth;
            if (interestForThisMonth > 0) {
              if (!isFirstIDCPayment) {
                minIDCEMI = interestForThisMonth;
                isFirstIDCPayment = true;
              }
              maxIDCEMI = interestForThisMonth;
            }
          }
        }
      }

      double currentPL1 = (pl1Amount > 0 && m >= pl1StartMonth) ? pl1EMI : 0;
      double currentPL2 = (pl2Amount > 0 && m >= pl2StartMonth) ? pl2EMI : 0;
      double totalOutflow = hlPayment + currentPL1 + currentPL2;

      if (m > 0) {
        if (m <= possessionMonths)
          runningPrePossessionTotal += totalOutflow;
        else
          runningPostPossessionTotal += totalOutflow;
      }

      monthlyLedger.add({
        'month': m,
        'disbursement': currentDisbursement,
        'activeSlabs': (m > fundingEndMonth)
            ? 'Max'
            : ((m - startMonth) / interval).floor() + 1,
        'cumulativeDisbursement': cumulativeDisbursement,
        'outstandingBalance': max(0, outstandingBalance),
        'hlComponent': hlPayment,
        'interestPart': interestForThisMonth,
        'principalPart': principalRepaidThisMonth,
        'isFullEMI': isFullEMI,
        'pl1': currentPL1,
        'totalOutflow': totalOutflow,
      });
    }

    double monthlyIDCEMI = (totalIDC > 0 && possessionMonths > 0)
        ? totalIDC / possessionMonths
        : 0;

    // --- FINAL METRICS ---
    double hlPaymentsMade = max(
      0,
      totalHoldingMonths - (realHomeLoanStartMonth - 1),
    );
    double pl1PaymentsMade = max(0, totalHoldingMonths - pl1StartMonth);
    double pl2PaymentsMade = max(0, totalHoldingMonths - pl2StartMonth);

    double hlInterestPaid = calculateTotalInterest(
      hlAmount,
      hlRate,
      hlTerm,
      hlPaymentsMade,
    );
    double pl1InterestPaid = calculateTotalInterest(
      pl1Amount,
      pl1Rate,
      pl1Term,
      pl1PaymentsMade,
    );
    double pl2InterestPaid = calculateTotalInterest(
      pl2Amount,
      pl2Rate,
      pl2Term,
      pl2PaymentsMade,
    );

    double totalEMIPaid =
        (hlEMI * hlPaymentsMade) +
        (pl1EMI * pl1PaymentsMade) +
        (pl2EMI * pl2PaymentsMade) +
        totalIDC;

    // ✅ Fix ROI Denominator
    double totalActualInvestment = dpAmount + totalEMIPaid;

    double baseExitPrice = getSafeValue(selections['selectedExitPrice']);
    double saleValue = size * baseExitPrice;

    double hlOutstandingFinal = calculateOutstanding(
      hlAmount,
      hlRate,
      hlTerm,
      hlPaymentsMade,
    );
    double pl1OutstandingFinal = calculateOutstanding(
      pl1Amount,
      pl1Rate,
      pl1Term,
      pl1PaymentsMade,
    );
    double pl2OutstandingFinal = calculateOutstanding(
      pl2Amount,
      pl2Rate,
      pl2Term,
      pl2PaymentsMade,
    );
    double totalOutstandingFinal =
        hlOutstandingFinal + pl1OutstandingFinal + pl2OutstandingFinal;

    double leftoverCash = saleValue - totalOutstandingFinal;
    double netProfit =
        leftoverCash -
        totalActualInvestment; // Net Gain = Cash in Hand - Cash Invested
    double roi = totalActualInvestment > 0
        ? (netProfit / totalActualInvestment) * 100
        : 0;

    // --- SCENARIOS ---
    List<Map<String, dynamic>> scenarios = [];
    Set<double> prices = {baseExitPrice};
    if (selections['scenarioExitPrices'] != null) {
      for (var p in selections['scenarioExitPrices'])
        prices.add(getSafeValue(p));
    }
    List<double> sortedPrices = prices.where((p) => p > 0).toList()..sort();

    for (double price in sortedPrices) {
      double sSaleValue = size * price;
      double sLeftover = sSaleValue - totalOutstandingFinal;
      double sNetProfit = sLeftover - totalActualInvestment;
      double sRoi = totalActualInvestment > 0
          ? (sNetProfit / totalActualInvestment) * 100
          : 0;

      scenarios.add({
        'exitPrice': price,
        'saleValue': sSaleValue,
        'leftoverCash': sLeftover,
        'netProfit': sNetProfit,
        'roi': sRoi,
        'isSelected': price == baseExitPrice,
      });
    }

    // --- CONSTRUCT FINAL REPORT (Matches Backend Structure) ---
    return {
      'detailedBreakdown': {
        'propertySize': size,
        'totalCost': totalCost,
        'totalCashInvested': totalCashInvested,
        'totalLoanOutstanding': totalOutstandingFinal,
        'homeLoanEMI': hlEMI,
        'personalLoan1EMI': pl1EMI,
        'personalLoan2EMI': pl2EMI,
        'gstCost': gstCost,
        'stampDutyCost': stampDutyCost,
        'homeLoanAmount': hlAmount,
        'personalLoan1Amount': pl1Amount,
        'personalLoan2Amount': pl2Amount,
        'downPaymentAmount': dpAmount,
        'homeLoanShare': hlShare,
        'personalLoan1Share': pl1Share,
        'personalLoan2Share': pl2Share,
        'downPaymentShare': dpShare,
        'totalInterestPaid':
            hlInterestPaid + pl1InterestPaid + pl2InterestPaid + totalIDC,
        'totalEMIPaid': totalEMIPaid,
        'totalIDC': totalIDC,
        'monthlyIDCEMI': monthlyIDCEMI,

        // ✅ RICH OBJECTS (Matches Backend)
        'idcReport': {
          'schedule': idcSchedule,
          'grandTotalInterest': grandTotalInterest,
          'minMonthlyInterest': baseSlabInterest,
          'maxMonthlyInterest': baseSlabInterest * slabsCount,
          'cutoffMonth': interestCutoffMonth,
        },
        'monthlyLedger': monthlyLedger,

        'saleValue': saleValue,
        'leftoverCash': leftoverCash,
        'netGainLoss': netProfit,
        'roi': roi,
        'exitPrice': baseExitPrice,
        'years': yearsDisplay,
        'prePossessionTotal': runningPrePossessionTotal,
        'postPossessionTotal':
            (hlEMI + pl1EMI + pl2EMI) *
            max(0, totalHoldingMonths - possessionMonths),
        'possessionMonths': possessionMonths,
        'totalHoldingMonths': totalHoldingMonths,
        'homeLoanStartMonth': realHomeLoanStartMonth,
        'postPossessionEMI': hlEMI + pl1EMI + pl2EMI,
        'postPossessionMonths': max(0, totalHoldingMonths - possessionMonths),
      },
      'multipleScenarios': scenarios,
    };
  }
}
