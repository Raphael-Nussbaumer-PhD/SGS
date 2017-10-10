function CY = SGS_varcovar(nx,ny,parm)


%% * *INPUT CEHCKING*
% This section of the code generates a valid parm structure based on the
% inputted parm. If some parm value haven't been input, this section will
% fill automatically with defautl value. This may not allowed be the best.


% Paramter settings
if ~isfield(parm, 'seed_path'),     parm.seed_path      = 'shuffle'; end
if ~isfield(parm, 'seed_U'),        parm.seed_U         = 'shuffle'; end
if ~isfield(parm, 'saveit'),        parm.saveit         = 1; end % bolean, save or not the result of simulation
if ~isfield(parm, 'name'),          parm.name           = ''; end % name use for saving file
if ~isfield(parm, 'n_real'),        parm.n_real  = 1; end

% Kriging parameter
parm.k.covar = kriginginitiaite(parm.k.covar);
if ~isfield(parm, 'k') || ~isfield(parm.k, 'method'),  parm.k.method = 'sbss'; end
if ~isfield(parm, 'k') || ~isfield(parm.k, 'nb'),  parm.k.nb = 30; end

if ~isfield(parm, 'k') || ~isfield(parm.k, 'wradius')
    parm.k.wradius  = 3;
end
k = parm.k;


% Path
if ~isfield(parm, 'path'),          parm.path            = 'linear'; end
if ~isfield(parm, 'path_random'),   parm.path_random     = 1; end
if ~isfield(parm, 'mg'),            parm.mg              = 1; end


if ~isfield(parm, 'cstk_s') % cstk_s is the scale at which cst is switch on
    if ~isfield(parm, 'cstk'),      parm.cstk           = 1; end % constant path and kriging weight activated or not
    if parm.cstk
        parm.cstk_s = 0; % will never use cstk
    else
        parm.cstk_s = Inf; % will always use cstk
    end
end



%% 1. Creation of the grid an path
[Y, X] = ndgrid(1:ny,1:nx);

%% 2. Define Path
Path = nan(ny,nx);

if parm.mg
   sx = 1:ceil(log(nx+1)/log(2));
   sy = 1:ceil(log(ny+1)/log(2));
   sn = max([numel(sy), numel(sx)]);
   nb = nan(sn,1);
   start = zeros(sn+1,1);
   dx = nan(sn,1); dy = nan(sn,1);
   path = nan(nx*ny,1);
   for i_scale = 1:sn
       if i_scale < parm.seed_path
           rng('shuffle');
       else
           rng('default')
       end

       dx(i_scale) = 2^(sn-sx(min(i_scale,end)));
       dy(i_scale) = 2^(sn-sy(min(i_scale,end)));
       [Y_s,X_s] = ndgrid(1:dy(i_scale):ny,1:dx(i_scale):nx); % matrix coordinate
       id = find(isnan(Path(:)) & ismember([Y(:) X(:)], [Y_s(:) X_s(:)], 'rows'));
       nb(i_scale) = numel(id);
       start(i_scale+1) = start(i_scale)+nb(i_scale);
       path( start(i_scale)+(1:nb(i_scale)) ) = id(randperm(nb(i_scale)));
       Path(path( start(i_scale)+(1:nb(i_scale)) )) = start(i_scale)+(1:nb(i_scale));
   end
else
   id=find(isnan(Path));
   path = id(randperm(numel(id)));
   Path(path) = 1:numel(id);
   dx=1; dy=1; nb = numel(id); start=[0 nb]; sn=1;
end


%% 3. Initialization Spiral Search

% Initialize spiral search stuff which don't change
x = ceil( min(k.covar(1).range(2)*k.wradius, nx));
y = ceil( min(k.covar(1).range(1)*k.wradius, ny));
[ss_Y, ss_X] = ndgrid(-y:y, -x:x);% grid{i_scale} of searching windows
ss_dist = sqrt( (ss_X/k.covar(1).range(2)).^2 + (ss_Y/k.covar(1).range(1)).^2); % find distence
ss_id_1 = find(ss_dist <= k.wradius); % filter node behind radius.
rng(parm.seed_search);
ss_id_1 = ss_id_1(randperm(numel(ss_id_1)));
[~, ss_id_2] = sort(ss_dist(ss_id_1)); % sort according distence.
ss_X_s=ss_X(ss_id_1(ss_id_2)); % sort the axis
ss_Y_s=ss_Y(ss_id_1(ss_id_2));
ss_n=numel(ss_X_s); %number of possible neigh


if parm.mg
    ss_scale=sn*ones(size(ss_X));
    for i_scale = sn-1:-1:1
        x_s = [-fliplr(dx(i_scale):dx(i_scale):x(end)) 0 dx(i_scale):dx(i_scale):x(end)]+(x+1);
        y_s = [-fliplr(dy(i_scale):dy(i_scale):y(end)) 0 dy(i_scale):dy(i_scale):y(end)]+(y+1);
        ss_scale(y_s,x_s)=i_scale;
    end
    ss_scale_s = ss_scale(ss_id_1(ss_id_2));
else
    ss_scale_s = sn*ones(size(ss_id_2));
end

%% 3. Initialization Covariance Lookup Table
ss_a0_C = zeros(ss_n,1);
ss_ab_C = zeros(ss_n);
for i=1:numel(k.covar)
    a0_h = sqrt(sum(([ss_Y_s(:) ss_X_s(:)]*k.covar(i).cx).^2,2));
    ab_h = squareform(pdist([ss_Y_s ss_X_s]*k.covar(i).cx));
    
    ss_a0_C = ss_a0_C + kron(k.covar(i).g(a0_h), k.covar(i).c0);
    ss_ab_C = ss_ab_C + kron(k.covar(i).g(ab_h), k.covar(i).c0);
end
% Transform ss.ab_C sparse?

%% 3. Initialization Covariance Lookup Table               
LambdaM = zeros(nx*ny,k.nb+1);

k_covar_c0 = sum([k.covar.c0]);
XY_i=[Y(path) X(path)];

%% 3. Loop

for i_scale = 1:sn
    ss_id = find(ss_scale_s<=i_scale);
    ss_XY_s = [ss_Y_s(ss_id) ss_X_s(ss_id)];
    ss_a0_C_s = ss_a0_C(ss_id);
    ss_ab_C_s = ss_ab_C(ss_id,ss_id);
    
    for i_pt = start(i_scale)+(1:nb(i_scale))
        n=0;
        neigh=nan(k.nb,3);
        for nn = 2:size(ss_XY_s,1) % 1 is the point itself... therefore unknown
            ijt = XY_i(i_pt,:)+ss_XY_s(nn,:);
            if ijt(1)>0 && ijt(2)>0 && ijt(1)<=ny && ijt(2)<=nx 
                if Path(ijt(1),ijt(2)) < i_pt % check if it,jt exist
                    n=n+1;
                    neigh(n,:) = [nn ijt];
                    if n >= k.nb
                        break;
                    end
                end
            end
        end
        
        neigh_id = (neigh(1:n,2:3)-1)*[1 ny]'+1;
        
        a0_C = ss_a0_C_s(neigh(1:n,1));
        ab_C = ss_ab_C_s(neigh(1:n,1), neigh(1:n,1));
        
        l = ab_C \ a0_C;
        S = k_covar_c0 - l'*a0_C;

        LambdaM(path(i_pt), neigh_id) = l./sqrt(S);
        LambdaM(path(i_pt), path(i_pt)) = -1/sqrt(S);
    end
end


CY = sparse(LambdaM) \ transpose(inv(sparse(LambdaM)));

end
