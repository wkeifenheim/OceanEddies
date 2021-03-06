function tracks = track_lnn(cell_eddies)
    p_eddies = cell(size(cell_eddies));
    eddies_mask = cell(size(cell_eddies));
    
    for i = 1:length(cell_eddies)
        p_eddies{i} = [[cell_eddies{i}.Lat]' [cell_eddies{i}.Lon]' ...
            [cell_eddies{i}.Amplitude]' [cell_eddies{i}.SurfaceArea]'];
        eddies_mask{i} = true(size(cell_eddies{i}));
    end
    
    tracks = stitch_lnn(p_eddies);
end

function [ tracks ] = stitch_lnn( eddies )
% Will use LNN tracking to provide cell array with [lat lon tstep index] matrices
% as the values
% eddies: cell-array of matrices formatted [lat lon amp sa]
    tracks = {};
    next_id = 1;

    targs = zeros(size(eddies{1},1),(size(eddies{1},2)+2));
    targs(:,1:4) = eddies{1};

    gateDist = 100;

    for t = 2:length(eddies)

        if isempty(eddies{t})
            continue
        end

        queries = targs;
        targs = zeros(size(eddies{t},1),(size(eddies{t},2)+2));
        targs(:,1:4) = eddies{t};

        numiter = 1;
        while numiter < 5
            [qrows ~] = find(~queries(:,5) & queries(:,6));
            [trows ~] = find(~targs(:,6));
            [knnidx ~] = knnsearch(targs(trows,[1 2]),queries(qrows,[1 2]));

            try
                dists = distance(queries(qrows,1),queries(qrows,2),...
                    targs(trows(knnidx),1),targs(trows(knnidx),2));
                dists = deg2km(dists);
            catch err
                numiter = 5;
                continue
            end

            if isempty(find(dists<gateDist, 1))
                numiter = 5;
                continue
            end

            [~, sortidx] = sort(dists);

            for ed = 1:length(sortidx)

                no_matches = dists(sortidx(ed))>gateDist;
                target_avail = ~targs(trows(knnidx(sortidx(ed))),6);

                % a good match between 0.25 and 2.75x amp and sa
                q_amp = queries(qrows(sortidx(ed)),3);
                q_sa = queries(qrows(sortidx(ed)),4);
                t_amp = targs(trows(knnidx(sortidx(ed))),3);
                t_sa = targs(trows(knnidx(sortidx(ed))),4);
                good_match = (q_amp > 0.25*t_amp &&...
                    q_amp < 2.75*t_amp &&...
                    q_sa > 0.25*t_sa &&...
                    q_sa < 2.75*t_sa &&...
                    target_avail);

                if no_matches
                    break
                elseif good_match
                    id = queries(qrows(sortidx(ed)),6);
                    queries(qrows(sortidx(ed)),5) = id;
                    targs(trows(knnidx(sortidx(ed))),6) = id;
                    tlat = targs(trows(knnidx(sortidx(ed))),1);
                    tlon = targs(trows(knnidx(sortidx(ed))),2);
                    tracks{id}(end+1,:) = [tlat tlon t trows(knnidx(sortidx(ed)))];
                end
            end

            numiter = numiter + 1;

        end

        numiter = 1;
        while numiter < 5
            [qrows ~] = find(~queries(:,5) & ~queries(:,6));
            [trows ~] = find(~targs(:,6));

            if isempty(trows)
                numiter = 5;
                continue
            end

            [knnidx ~] = knnsearch(targs(trows,[1 2]),queries(qrows,[1 2]));

            try
                dists = distance(queries(qrows,1),queries(qrows,2),...
                    targs(trows(knnidx),1),targs(trows(knnidx),2));
                dists = deg2km(dists);
            catch err
                x = 1;
            end

            if isempty(find(dists<150, 1))
                numiter = 5;
                continue
            end

            [~, sortidx] = sort(dists);

            for ed = 1:length(sortidx)

                no_matches = dists(sortidx(ed))>gateDist;
                target_avail = ~targs(trows(knnidx(sortidx(ed))),6);

                % a good match between 0.25 and 2.75x amp and sa
                q_amp = queries(qrows(sortidx(ed)),3);
                q_sa = queries(qrows(sortidx(ed)),4);
                t_amp = targs(trows(knnidx(sortidx(ed))),3);
                t_sa = targs(trows(knnidx(sortidx(ed))),4);
                good_match = (q_amp > 0.25*t_amp &&...
                    q_amp < 2.75*t_amp &&...
                    q_sa > 0.25*t_sa &&...
                    q_sa < 2.75*t_sa &&...
                    target_avail);

                if no_matches
                    break
                elseif good_match
                    queries(qrows(sortidx(ed)),5) = next_id;
                    targs(trows(knnidx(sortidx(ed))),6) = next_id;
                    qlat = queries(qrows(sortidx(ed)),1);
                    qlon = queries(qrows(sortidx(ed)),2);
                    tlat = targs(trows(knnidx(sortidx(ed))),1);
                    tlon = targs(trows(knnidx(sortidx(ed))),2);
                    tracks{next_id} = [qlat qlon (t-1) qrows(sortidx(ed))];
                    tracks{next_id}(2,:) = [tlat tlon t trows(knnidx(sortidx(ed)))];
                    next_id = next_id + 1;
                end
            end

            numiter = numiter+1;
        end

        disp(['t  ' num2str(t)]);
    end
end

