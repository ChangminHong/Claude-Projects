function outFile = Changmin_Excels_Merge(inDir, outFile)
%MERGE_Excel_FILES  폴더 안의 여러 엑셀 파일을 하나로 합칩니다.
%
%   merge_d2d_files()
%   merge_d2d_files(inDir)
%   outFile = merge_d2d_files(inDir, outFile)
%
%   D2D 폴더처럼 소자별 측정 파일(D1.xls, D2.xls, ... D10.xls)이 모여 있는
%   폴더를 읽어 하나의 워크북으로 합칩니다. 각 파일에는 이름이 "Run"으로
%   시작하는 시트가 정확히 하나만 있다고 가정하며(Run 번호는 파일마다 달라도
%   상관없습니다), 그 시트의 열 구성은 아래와 같습니다.
%
%       DrainI | DrainV | GateV
%
%   결과 워크북의 1열에는 공통 스윕축(DrainV 또는 GateV 중 실제로 변하는 쪽)이
%   들어가고, 2열부터 N+1열까지는 각 파일의 DrainI 가 파일 이름 순서대로
%   한 파일당 한 열씩 붙습니다.
%
%   파일 개수와 행 수는 미리 정해두지 않고 폴더 내용에서 그때그때 읽습니다.
%   다만 합치기 전에 모든 파일의 행 수가 같은지 검사하며, 하나라도 다르면
%   "Cycle 조건이 통일되어 있지 않습니다" 오류를 내고 중단합니다.
%   (오류 식별자: merge_d2d_files:cycleMismatch)
%
%   기본값: inDir   = 'D2D'
%           outFile = Changmin_Excels_Merged.xlsx  (대상 폴더와 같은 위치에 생성)
%
%   사용 예:
%       merge_d2d_files('D2D');
%       merge_d2d_files('D2D', '다른이름.xlsx');

    if nargin < 1 || isempty(inDir)
        inDir = 'D2D';  % 폴더이름을 항상 정해야 합니다!!
    end
    if ~isfolder(inDir)
        error('merge_d2d_files:dirNotFound', '폴더를 찾을 수 없습니다: %s', inDir);
    end
    if nargin < 2 || isempty(outFile)
        % 결과 파일은 폴더 '바깥'에 만듭니다. 폴더 안에 두면 다음 번 실행 때
        % 입력 파일로 다시 읽혀 자기 자신을 합치려 들기 때문입니다.
        parentDir = fileparts(strip_trailing_sep(inDir));
        outFile   = fullfile(parentDir, 'Changmin_Excels_Merged.xlsx');
    end

    % ---------------------------------------------------------------------
    % 1) 폴더 안의 엑셀 파일을 모아 파일 이름 뒤의 숫자 순으로 정렬합니다.
    %    사전순으로 두면 D10 이 D2 보다 앞에 오므로 열 순서가 뒤섞입니다.
    % ---------------------------------------------------------------------
    listing = [dir(fullfile(inDir, '*.xls')); dir(fullfile(inDir, '*.xlsx'))];
    listing = listing(~[listing.isdir]);
    files   = string({listing.name}');

    % 엑셀 임시 파일(~$...)과, 혹시 폴더 안에 있을 결과 파일은 제외합니다.
    files = files(~startsWith(files, "~$"));
    files = files(~strcmpi(files, string(get_name_ext(outFile))));
    if isempty(files)
        error('merge_d2d_files:noExcelFile', ...
              '%s 안에 읽을 수 있는 엑셀 파일(.xls/.xlsx)이 없습니다.', inDir);
    end

    files   = sort(files);                    % 숫자가 같을 때를 대비한 기본 순서
    baseNm  = strings(numel(files), 1);
    fileNum = zeros(numel(files), 1);
    for k = 1:numel(files)
        [~, baseNm(k)] = fileparts(files(k));
        tok = regexp(baseNm(k), '(\d+)\s*$', 'tokens', 'once');
        if isempty(tok)
            fileNum(k) = Inf;                 % 끝에 숫자가 없으면 맨 뒤로
        else
            fileNum(k) = str2double(tok{1});
        end
    end
    [~, order] = sortrows([fileNum, (1:numel(files))']);   % 동점이면 이름순 유지
    files  = files(order);
    baseNm = baseNm(order);

    nFile = numel(files);
    fprintf('%s 폴더에서 엑셀 파일 %d개를 찾았습니다: %s\n', ...
            inDir, nFile, strjoin(baseNm, ', '));

    % ---------------------------------------------------------------------
    % 2) 파일마다 Run 시트를 찾아 DrainI 와 스윕축을 읽습니다.
    %    "Run 시트는 파일당 하나"가 전제이므로, 0개거나 2개 이상이면 어느 것을
    %    써야 할지 알 수 없습니다. 임의로 고르지 않고 오류로 알립니다.
    % ---------------------------------------------------------------------
    drainI  = cell(nFile, 1);   % 파일별 전류 데이터
    sweepV  = cell(nFile, 1);   % 파일별 스윕축 (나중에 서로 비교하는 용도)
    axisNm  = strings(nFile, 1);
    runNm   = strings(nFile, 1);

    for k = 1:nFile
        fPath = fullfile(inDir, files(k));

        allSheets = string(sheetnames(fPath));
        runSheets = allSheets(startsWith(allSheets, "Run", 'IgnoreCase', true));
        if isempty(runSheets)
            error('merge_d2d_files:noRunSheet', ...
                  '"%s" 파일에 "Run"으로 시작하는 시트가 없습니다. (시트 목록: %s)', ...
                  files(k), strjoin(allSheets, ', '));
        elseif numel(runSheets) > 1
            error('merge_d2d_files:multipleRunSheet', ...
                  ['"%s" 파일에 "Run" 시트가 %d개 있습니다 (%s). ' ...
                   '파일당 하나만 있어야 합니다.'], ...
                  files(k), numel(runSheets), strjoin(runSheets, ', '));
        end
        runNm(k) = runSheets(1);

        T   = localReadSheet(fPath, runNm(k));
        key = localNormalizeNames(T.Properties.VariableNames);

        iI  = find(key == "draini", 1);
        iDV = find(key == "drainv", 1);
        iGV = find(key == "gatev",  1);
        if isempty(iI)
            error('merge_d2d_files:noDrainI', ...
                  '"%s" 파일의 "%s" 시트에 DrainI 열이 없습니다. (읽어온 열 이름: %s)', ...
                  files(k), runNm(k), strjoin(T.Properties.VariableNames, ', '));
        end
        if isempty(iDV) && isempty(iGV)
            error('merge_d2d_files:noSweep', ...
                  '"%s" 파일의 "%s" 시트에 DrainV 도 GateV 도 없습니다.', ...
                  files(k), runNm(k));
        end

        Ik  = localColumn(T, iI);
        DVk = localColumn(T, iDV);
        GVk = localColumn(T, iGV);

        % 고정되어 있지 않고 실제로 변하는 쪽이 스윕축입니다.
        % 출력특성(Id-Vd)이면 DrainV 가, 전달특성(Id-Vg)이면 GateV 가 됩니다.
        nDV = numel(unique(DVk(~isnan(DVk))));
        nGV = numel(unique(GVk(~isnan(GVk))));
        if nGV > nDV
            sweepV{k} = GVk;  axisNm(k) = "GateV";
        elseif nDV > 0
            sweepV{k} = DVk;  axisNm(k) = "DrainV";
        else
            sweepV{k} = GVk;  axisNm(k) = "GateV";
        end

        drainI{k} = Ik;
        fprintf('  %-12s %-10s 데이터 %4d개, 스윕축 = %s\n', ...
                files(k), runNm(k), numel(Ik), axisNm(k));
    end

    % ---------------------------------------------------------------------
    % 3) 모든 파일의 행 수가 정확히 같은지 검사합니다.
    %    행 수가 다르다는 것은 파일마다 Cycle 측정 조건(스윕 점 개수)이 다르다는
    %    뜻입니다. 행 번호로 열을 나란히 붙이면 서로 다른 조건의 데이터가 같은
    %    줄에 놓이므로, 억지로 합치지 않고 중단합니다.
    % ---------------------------------------------------------------------
    rowCount = cellfun(@numel, drainI);
    if any(rowCount == 0)
        error('merge_d2d_files:emptySheet', ...
              '데이터가 하나도 없는 파일이 있습니다: %s', ...
              strjoin(baseNm(rowCount == 0), ', '));
    end
    if numel(unique(rowCount)) > 1
        detail = strjoin(compose("%s=%d행", baseNm(:), rowCount(:)), ', ');
        error('merge_d2d_files:cycleMismatch', ...
              'Excels 조건이 통일되어 있지 않습니다. (파일별 행 수: %s)', detail);
    end
    nRows = rowCount(1);

    fprintf('행 수 검사 통과: %d개 파일 모두 %d행\n', nFile, nRows);

    % ---------------------------------------------------------------------
    % 4) 스윕축이 파일끼리 일치하는지 확인한 뒤 행렬을 조립합니다.
    %    1열 = 스윕축, 2열 ~ nFile+1열 = 각 파일의 DrainI
    % ---------------------------------------------------------------------
    if numel(unique(axisNm)) > 1
        warning('merge_d2d_files:mixedAxis', ...
                '파일마다 스윕축이 다릅니다 (%s). 첫 번째 파일 "%s" 의 %s 를 사용합니다.', ...
                strjoin(unique(axisNm), '/'), baseNm(1), axisNm(1));
    end

    % 위에서 행 수가 모두 같음을 보장했으므로 어느 파일을 기준으로 삼아도 됩니다.
    xRef = sweepV{1};
    tol  = 1e-9 + 1e-6 * max(abs(xRef(~isnan(xRef))));   % 절대 오차 + 상대 오차 여유분
    for k = 2:nFile
        % 행 수는 같아도 스윕 값 자체가 다를 수 있습니다. 여기서 경고가 뜨면
        % 행 번호로 맞춘 정렬이 어긋났다는 뜻입니다.
        d = abs(sweepV{k} - xRef);
        if any(d > tol)
            warning('merge_d2d_files:axisMismatch', ...
                    ['"%s" 파일의 %s 축이 "%s" 파일과 다릅니다 (최대 편차 %g). ' ...
                     '행 번호 순서대로 붙이므로 데이터가 어긋날 수 있습니다.'], ...
                    baseNm(k), axisNm(k), baseNm(1), max(d));
        end
    end

    M = nan(nRows, nFile + 1);
    M(:, 1) = xRef;
    for k = 1:nFile
        M(:, k + 1) = drainI{k};
    end

    % ---------------------------------------------------------------------
    % 5) 합쳐진 결과를 새 엑셀 파일로 저장합니다.
    %    열 이름은 파일 이름을 그대로 씁니다(DrainI_D1 ...). 어느 소자의
    %    데이터인지가 Run 번호보다 알아보기 쉽기 때문입니다.
    % ---------------------------------------------------------------------
    header = [cellstr(axisNm(1)), cellstr("DrainI_" + baseNm(:)')];
    if isfile(outFile)
        delete(outFile);            % 이전에 열 수가 더 많던 결과가 남는 것을 방지
    end
    writecell(header, outFile, 'Sheet', 'Merged', 'Range', 'A1');
    writematrix(M,    outFile, 'Sheet', 'Merged', 'Range', 'A2');

    fprintf('%s 저장 완료 (%d행 x %d열: %s 1열 + DrainI %d열)\n', ...
            outFile, nRows, nFile + 1, axisNm(1), nFile);
end

% =========================================================================
% 보조 함수
% =========================================================================
function p = strip_trailing_sep(p)
% 'D2D/' 처럼 끝에 구분자가 붙어 있으면 fileparts 가 폴더 이름을 빈 값으로
% 돌려주므로 미리 떼어냅니다.
    p = char(p);
    while ~isempty(p) && (p(end) == '/' || p(end) == '\')
        p(end) = [];
    end
end

function n = get_name_ext(p)
% 경로에서 '이름.확장자' 부분만 돌려줍니다.
    [~, n, e] = fileparts(char(p));
    n = [n e];
end

function T = localReadSheet(file, sheet)
% 시트 하나를 읽습니다. MATLAB 버전이 지원하면 원본 헤더 문자열을 그대로 보존합니다.
    try
        T = readtable(file, 'Sheet', sheet, 'VariableNamingRule', 'preserve');
    catch
        T = readtable(file, 'Sheet', sheet);      % 구버전 MATLAB 대응
    end
end

function key = localNormalizeNames(names)
% 헤더 표기를 통일합니다. 'Drain I', 'DrainI', 'drain_i', 'x_DrainI' -> "draini"
    key = lower(string(names));
    key = regexprep(key, '^x_', '');
    key = regexprep(key, '[^a-z]', '');
end

function v = localColumn(T, idx)
% 인덱스로 숫자 열을 가져옵니다. 인덱스가 비어 있으면 [], 숫자가 아니면 NaN 을 돌려줍니다.
    if isempty(idx)
        v = [];
        return;
    end
    v = T{:, idx};
    if ~isnumeric(v)
        v = str2double(string(v));
    end
    v = double(v(:));
end
